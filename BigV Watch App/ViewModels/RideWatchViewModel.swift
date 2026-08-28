//
//  RideWatchViewModel.swift
//  BigV Watch App
//

import Foundation

/// Coordinates the wrist: the phone link, the sensor session and the two haptics.
///
/// The single publisher on this side, mirroring the phone's rule. It owns no ride
/// truth — `phase` and every metric arrive from the phone, and the only thing the
/// Watch originates is a heart rate and a button press.
@Observable
@MainActor
final class RideWatchViewModel {

   // MARK: - Dependencies

   private let rideWatchLinkManager: RideWatchLinkManager
   private let rideWatchWorkoutManager: RideWatchWorkoutManager

   // MARK: - Initialization

   init(
      rideWatchLinkManager: RideWatchLinkManager = RideWatchLinkManager(),
      rideWatchWorkoutManager: RideWatchWorkoutManager = RideWatchWorkoutManager()
   ) {
      self.rideWatchLinkManager = rideWatchLinkManager
      self.rideWatchWorkoutManager = rideWatchWorkoutManager
   }

   // MARK: - Published State

   /// The phone's phase, from whichever arrived last: a mirror or a receipt.
   private(set) var phase: RidePhase = .idle

   private(set) var linkState: RideWatchLinkState = .activating

   private var snapshot: RideWatchMetricsSnapshot?
   private var heartRateReading: RideWatchHeartRateReading?

   /// A transient word about the last command. Standing conditions live on
   /// `linkState` instead.
   private var notice: String?

   private var hasAdoptedPhase = false

   private var linkTask: Task<Void, Never>?
   private var sensorTask: Task<Void, Never>?
   private var noticeTask: Task<Void, Never>?

   // MARK: - Lifecycle

   /// Sweeps any orphaned sensor session, asks for Health access, then opens the
   /// link.
   ///
   /// Strictly ordered: recovery has to finish before anything can start a session,
   /// or it could recover the session we just opened and end it.
   func activate() async {
      await rideWatchWorkoutManager.endOrphanedSession()
      await rideWatchWorkoutManager.requestAuthorization()

      let events = rideWatchLinkManager.activate()

      linkTask?.cancel()
      linkTask = Task { [weak self] in
         for await event in events {
            guard let self else { return }
            self.handle(event)
         }
      }
   }

   // MARK: - Intent

   func send(_ command: RideRemoteCommand) {
      rideWatchLinkManager.send(command)
   }

   // MARK: - Headline

   var speed: String {
      guard let snapshot, snapshot.hasGPSFix else { return RideFormatters.placeholder }
      return RideFormatters.speed(snapshot.speed)
   }

   var speedUnit: String { RideFormatters.Unit.speed }

   // MARK: - Metrics

   var distance: String {
      RideFormatters.distance(snapshot?.distance ?? 0)
   }

   var distanceUnit: String { RideFormatters.Unit.distance }

   var elapsedTime: String {
      RideFormatters.duration(snapshot?.elapsedTime ?? 0)
   }

   var heartRate: String {
      guard let heartRateReading, heartRateReading.isFresh() else {
         return RideFormatters.placeholder
      }
      return RideFormatters.heartRate(heartRateReading.beatsPerMinute)
   }

   var heartRateUnit: String { RideFormatters.Unit.heartRate }

   var isSensingHeartRate: Bool { rideWatchWorkoutManager.isSensing }

   /// Whether the newest snapshot is recent enough to read as live. Event-driven:
   /// it turns false when an old payload lands, not on a timer.
   var hasLiveMetrics: Bool {
      guard phase.isActive, let snapshot else { return true }
      return snapshot.isFresh()
   }

   // MARK: - Status

   /// Mirrors the phone's own vocabulary so the two screens never disagree.
   var statusText: String {
      switch phase {
         case .idle: "Ready"
         case .acquiringGPS: "Acquiring GPS"
         case .recording: (snapshot?.isMoving ?? false) ? "Recording" : "Stopped"
         case .paused: "Paused"
         case .finished: "Complete"
      }
   }

   var hasGPSFix: Bool { snapshot?.hasGPSFix ?? false }

   /// One line of trouble. A command outcome wins over a standing condition,
   /// which wins over a sensor that never came up.
   var noticeText: String? {
      notice ?? linkState.message ?? rideWatchWorkoutManager.failure
   }

   // MARK: - Controls

   var controls: [RideWatchControl] {
      switch phase {
         case .idle:
            [RideWatchControl(command: .start, title: "START", role: .go)]

         case .acquiringGPS:
            [RideWatchControl(command: .end, title: "CANCEL", role: .stop)]

         case .recording:
            [
               RideWatchControl(command: .pause, title: "PAUSE", role: .hold),
               RideWatchControl(command: .end, title: "END", role: .stop)
            ]

         case .paused:
            [
               RideWatchControl(command: .resume, title: "RESUME", role: .go),
               RideWatchControl(command: .end, title: "END", role: .stop)
            ]

         case .finished:
            [RideWatchControl(command: .start, title: "NEW RIDE", role: .go)]
      }
   }

   // MARK: - Event Handling

   private func handle(_ event: RideWatchLinkManager.Event) {
      switch event {
         case .linkChanged(let state):
            linkState = state

         case .metrics(let incoming):
            apply(incoming)

         case .receipt(let receipt):
            adopt(receipt.phase)
            show(receipt.outcome.message)

         case .commandUndelivered:
            show(RideRemoteCommandOutcome.undelivered.message)
      }
   }

   /// A queued context update can land after the live message it was meant to back
   /// up, so an older snapshot must never overwrite a newer one.
   private func apply(_ incoming: RideWatchMetricsSnapshot) {
      if let snapshot, incoming.capturedAt < snapshot.capturedAt { return }

      snapshot = incoming
      adopt(incoming.phase)
   }

   private func adopt(_ incoming: RidePhase) {
      let isFirstPhase = !hasAdoptedPhase
      hasAdoptedPhase = true

      guard incoming != phase || isFirstPhase else { return }

      phase = incoming

      // Opening the app mid-ride must engage the sensor without buzzing as though
      // the ride had just begun.
      syncSensor(to: incoming, silently: isFirstPhase)
   }

   // MARK: - Sensor

   private func syncSensor(to phase: RidePhase, silently: Bool) {
      if phase.isActive {
         guard sensorTask == nil else { return }

         startSensing()
         if !silently { RideWatchHaptics.playRideStart() }
      } else {
         guard sensorTask != nil else { return }

         stopSensing()
         if !silently { RideWatchHaptics.playRideEnd() }
      }
   }

   private func startSensing() {
      let readings = rideWatchWorkoutManager.startSensing()

      sensorTask = Task { [weak self] in
         for await reading in readings {
            guard let self else { return }
            self.apply(reading)
         }
      }
   }

   private func stopSensing() {
      sensorTask?.cancel()
      sensorTask = nil

      rideWatchWorkoutManager.stopSensing()
      heartRateReading = nil
      rideWatchLinkManager.reportHeartRateEnded()
   }

   private func apply(_ reading: RideWatchHeartRateReading) {
      guard reading.isPlausible else { return }

      heartRateReading = reading
      rideWatchLinkManager.report(reading)
   }

   // MARK: - Notices

   private func show(_ message: String?) {
      noticeTask?.cancel()
      notice = message

      guard message != nil else { return }

      noticeTask = Task { [weak self] in
         try? await Task.sleep(for: .seconds(3))
         guard !Task.isCancelled else { return }
         self?.notice = nil
      }
   }
}
