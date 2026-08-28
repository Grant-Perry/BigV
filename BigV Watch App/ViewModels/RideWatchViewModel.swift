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

   /// Sensor start waits until the glance is frontmost. `startActivity()` inside
   /// a button action is how watchOS tosses the rider at the clock.
   private var wantsSensing = false
   private var isSceneActive = false

   /// The alert pulse from the last radar-bearing snapshot, so wrist haptics
   /// fire on edges only. `nil` until the first radar snapshot lands — that
   /// first sight of a mid-ride counter must set a baseline, not buzz.
   private var lastRadarAlertPulse: Int?

   private var activationTask: Task<Void, Never>?
   private var linkTask: Task<Void, Never>?
   private var sensorTask: Task<Void, Never>?
   private var senseStartTask: Task<Void, Never>?
   private var noticeTask: Task<Void, Never>?

   // MARK: - Lifecycle

   /// Reclaims any orphaned sensor session, asks for Health access, then opens
   /// the link. Safe to call again: the view `.task` restarts when watchOS
   /// blips inactive on a button tap, and a second pass must not park or
   /// restart anything.
   func activate() async {
      if activationTask == nil {
         activationTask = Task { [weak self] in
            await self?.activateOnce()
         }
      }

      await activationTask?.value
   }

   /// The system calls this when a workout session starts. That is what
   /// brings the glance back instead of leaving the rider on the clock.
   func handleWorkoutLaunch() async {
      wantsSensing = true
      isSceneActive = true
      await activate()
      startSensingIfFrontmost()
   }

   private func activateOnce() async {
      await rideWatchWorkoutManager.reclaimOrphanedSession()
      await rideWatchWorkoutManager.requestAuthorization()

      // Never mint a workout session from launch while idle. An idle session
      // sits in Health as an in-progress ride and is the first thing that
      // makes the phone's end-of-ride write fail. Mid-ride recovery still
      // starts: a reclaimed session, or the first active phase from the phone.
      //
      // Also do not call `startActivity()` from this `.task` itself. The
      // scene is often still inactive during launch, and watchOS then dumps
      // the glance.
      wantsSensing = rideWatchWorkoutManager.isSensing || phase.isActive
      startSensingIfFrontmost()

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

   func noteScene(isActive: Bool) {
      isSceneActive = isActive
      if isActive {
         startSensingIfFrontmost()
      }
   }

   func send(_ command: RideRemoteCommand) {
      // Own the glance immediately. Waiting for the phone is how Start used
      // to sit on idle while the button tap made the scene inactive and we
      // ended the workout — straight back to the watch face.
      if command == .start, !phase.isActive {
         adopt(.acquiringGPS)
      }

      rideWatchLinkManager.send(command)
   }

   // MARK: - Units

   /// The phone's preference, riding every snapshot. Imperial until the first
   /// snapshot lands — the same default the phone starts from.
   private var unitSystem: RideUnitSystem { snapshot?.unitSystem ?? .imperial }

   // MARK: - Headline

   var speed: String {
      guard let snapshot, snapshot.hasGPSFix else { return RideFormatters.placeholder }
      return RideFormatters.speed(snapshot.speed, system: unitSystem)
   }

   var speedUnit: String { unitSystem.speedUnit }

   // MARK: - Metrics

   var distance: String {
      RideFormatters.distance(snapshot?.distance ?? 0, system: unitSystem)
   }

   var distanceUnit: String { unitSystem.distanceUnit }

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

   var heartRateBeatsPerMinute: Double? {
      guard let heartRateReading, heartRateReading.isFresh() else { return nil }
      return heartRateReading.beatsPerMinute
   }

   var isSensingHeartRate: Bool { rideWatchWorkoutManager.isSensing }

   /// Whether the newest snapshot is recent enough to read as live. Event-driven:
   /// it turns false when an old payload lands, not on a timer.
   var hasLiveMetrics: Bool {
      guard phase.isActive, let snapshot else { return true }
      return snapshot.isFresh()
   }

   // MARK: - Status

   /// Phase only. Speed already says when the rider is sitting still — "Stopped"
   /// on a PAUSE/END glance reads like the workout died.
   var statusText: String {
      switch phase {
         case .idle: "Ready"
         case .acquiringGPS:
            snapshot?.locationIssue
               ?? snapshot?.horizontalAccuracy.map { "Phone GPS \(RideFormatters.accuracy($0, system: unitSystem))" }
               ?? "Phone GPS…"
         case .recording: "Recording"
         case .paused: "Paused"
         case .finished: "Complete"
      }
   }

   var hasGPSFix: Bool { snapshot?.hasGPSFix ?? false }

   // MARK: - Radar

   /// Whether the phone is mirroring a radar at all. Old phone builds and
   /// radar-less riders send no radar keys, and the glance shows nothing.
   var hasRadar: Bool { snapshot?.radarConnected != nil }

   var isRadarConnected: Bool { snapshot?.radarConnected == true }

   var radarTier: RideRadarThreatTier? { snapshot?.radarTier }

   var radarVehicleCount: Int { snapshot?.radarCount ?? 0 }

   var radarNearestMeters: Double? { snapshot?.radarNearest }

   var radarNearestDistance: String? {
      snapshot?.radarNearest.map { RideFormatters.radarDistance($0, system: unitSystem) }
   }

   /// One line of trouble. A command outcome wins over a standing condition,
   /// which wins over a sensor that never came up.
   var noticeText: String? {
      notice ?? snapshot?.locationIssue ?? linkState.message ?? rideWatchWorkoutManager.failure
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
            if state.allowsLiveMessages, let heartRateReading {
               rideWatchLinkManager.report(heartRateReading)
            }

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

      playRadarHapticIfNeeded(for: incoming)
      snapshot = incoming
      adopt(incoming.phase)
   }

   /// Taps the wrist when the phone's radar alert counter advances — edges
   /// only, so a snapshot stream at 1 Hz plus escalation pushes stays rare.
   private func playRadarHapticIfNeeded(for incoming: RideWatchMetricsSnapshot) {
      guard let pulse = incoming.radarAlertPulse else {
         lastRadarAlertPulse = nil
         return
      }

      defer { lastRadarAlertPulse = pulse }
      guard let lastRadarAlertPulse, pulse > lastRadarAlertPulse else { return }

      if incoming.radarTier == .high {
         RideWatchHaptics.playRadarDanger()
      } else {
         RideWatchHaptics.playRadarApproach()
      }
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
         wantsSensing = true
         if !silently { RideWatchHaptics.playRideStart() }
         startSensingIfFrontmost()
      } else {
         wantsSensing = false
         senseStartTask?.cancel()
         senseStartTask = nil

         guard sensorTask != nil || rideWatchWorkoutManager.isSensing else { return }

         parkSensing()
         if !silently { RideWatchHaptics.playRideEnd() }
      }
   }

   /// Only start the HealthKit session while the glance is actually on screen.
   /// `startActivity()` from a button or from a launch `.task` is how watchOS
   /// decides the app is not frontmost and throws the rider at the clock.
   private func startSensingIfFrontmost() {
      guard wantsSensing, sensorTask == nil, isSceneActive else { return }

      senseStartTask?.cancel()
      senseStartTask = Task { [weak self] in
         await Task.yield()
         guard let self, !Task.isCancelled else { return }
         guard self.wantsSensing, self.isSceneActive, self.sensorTask == nil else { return }
         self.startSensing()
      }
   }

   private func startSensing() {
      sensorTask = Task { [weak self] in
         guard let self else { return }

         // One more recover before minting a session. A leftover system
         // session plus a new `startActivity()` is a guaranteed trip to the clock.
         await self.rideWatchWorkoutManager.reclaimOrphanedSession()
         let readings = self.rideWatchWorkoutManager.startSensing()

         for await reading in readings {
            self.apply(reading)
         }
      }
   }

   private func parkSensing() {
      sensorTask?.cancel()
      sensorTask = nil

      rideWatchWorkoutManager.parkSensing()
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
