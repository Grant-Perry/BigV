//
//  RideSessionManager.swift
//  BigV
//

import CoreLocation
import Foundation
import SwiftData

/// Owns the live ride: lifecycle, the clock, and the one canonical `RideState`.
///
/// Every provider feeds this manager and this manager alone publishes state.
/// Nothing else in the app is allowed to compute ride metrics.
@Observable
@MainActor
final class RideSessionManager {

   // MARK: - Published State

   private(set) var state = RideState()

   /// The ride the most recent `end()` committed, so the summary can read its
   /// stored route back. `nil` until finalization lands, or when the ride
   /// produced nothing worth keeping.
   private(set) var finishedRideID: PersistentIdentifier?

   // MARK: - Private Properties

   private let locationManager: RideLocationManager
   private let rideStorageManager: RideStorageManager?
   private let rideFinalizer: RideFinalizer
   private let rideRouteRecorder: RideRouteRecorder
   private let routeGuidanceManager: RouteGuidanceManager?
   private let rideWatchManager: RideWatchManager?
   private var telemetryEngine: RideTelemetryEngine
   private var rideClock = RideClock()

   private var locationTask: Task<Void, Never>?
   private var clockTask: Task<Void, Never>?
   private var finalizeTask: Task<Void, Never>?
   private var authorizationTask: Task<Void, Never>?
   private var watchLinkTask: Task<Void, Never>?

   private var lastSampleAt: Date?
   private var lastHeartRateAt: Date?

   /// Displayed speed drops to zero when samples stop arriving for this long.
   private let sampleStalenessWindow: TimeInterval = 4

   /// Heart rate clears when the wrist stops feeding one for this long. Wider than
   /// the speed window because watchOS writes beats in batches, not per second.
   private let heartRateStalenessWindow: TimeInterval = 15

   // MARK: - Initialization

   /// Storage and Health are optional so previews and engine tests can build a
   /// session with no side effects.
   init(
      locationManager: RideLocationManager = RideLocationManager(),
      configuration: RideTelemetryEngine.Configuration = .default,
      rideStorageManager: RideStorageManager? = nil,
      rideHealthManager: RideHealthManager? = nil,
      rideRouteRecorder: RideRouteRecorder = RideRouteRecorder(),
      routeGuidanceManager: RouteGuidanceManager? = nil,
      rideWatchManager: RideWatchManager? = nil
   ) {
      self.locationManager = locationManager
      self.rideStorageManager = rideStorageManager
      self.rideFinalizer = RideFinalizer(
         rideStorageManager: rideStorageManager,
         rideHealthManager: rideHealthManager
      )
      self.rideRouteRecorder = rideRouteRecorder
      self.routeGuidanceManager = routeGuidanceManager
      self.rideWatchManager = rideWatchManager
      self.telemetryEngine = RideTelemetryEngine(configuration: configuration)
   }

   // MARK: - Lifecycle

   func start() {
      guard !state.phase.isActive else { return }

      telemetryEngine.reset()
      rideRouteRecorder.reset()
      rideClock.reset()
      state = RideState()
      finishedRideID = nil
      state.phase = .acquiringGPS
      lastSampleAt = nil

      ScreenAwakeService.setKeepAwake(true)
      startLocationStream()
      startClock()
      requestHealthAuthorization()
      mirrorToWatch()

      DebugPrint(mode: .sessionLifecycle, "Ride start requested")
   }

   func pause() {
      guard state.phase == .recording else { return }

      rideClock.beginPause()
      state.phase = .paused
      telemetryEngine.markSpeedStale()
      publishTelemetry()
      flushPendingWork()
      mirrorToWatch()

      DebugPrint(mode: .sessionLifecycle, "Ride paused")
   }

   func resume() {
      guard state.phase == .paused else { return }

      rideClock.endPause()
      lastSampleAt = nil
      state.phase = .recording
      mirrorToWatch()

      DebugPrint(mode: .sessionLifecycle, "Ride resumed")
   }

   func end() {
      guard state.phase.isActive else { return }

      // Cancelling before the first fix never produced a ride, so there is
      // nothing to summarize or export.
      guard state.startDate != nil else {
         returnToIdle()
         DebugPrint(mode: .sessionLifecycle, "Ride cancelled before first fix")
         return
      }

      // Ending mid-pause must not bill that pause as ride time.
      rideClock.endPause()

      stopStreams()
      ScreenAwakeService.setKeepAwake(false)

      state.endDate = .now
      telemetryEngine.markSpeedStale()
      publishTelemetry()
      refreshElapsedTime()

      let decision = RideRetentionPolicy.decision(
         distance: state.distance,
         sampleCount: telemetryEngine.acceptedSampleCount
      )

      if case .discard(let reason) = decision {
         discardRide(reason: reason)
         return
      }

      state.phase = .finished
      mirrorToWatch()

      DebugPrint(
         mode: .sessionLifecycle,
         "Ride ended: \(state.distance) m in \(state.elapsedTime) s, \(telemetryEngine.acceptedSampleCount) samples accepted, \(telemetryEngine.rejectedSampleCount) rejected"
      )

      finalizeTask = Task { [weak self] in
         await self?.finalizeRide()
      }
   }

   /// Clears a finished ride and returns to idle.
   ///
   /// An in-flight export is left running: the ride is already persisted and its
   /// workout link is still worth writing.
   func reset() {
      guard state.phase == .finished || state.phase == .idle else { return }
      returnToIdle()
   }

   private func returnToIdle() {
      stopStreams()
      ScreenAwakeService.setKeepAwake(false)
      telemetryEngine.reset()
      rideRouteRecorder.reset()
      rideClock.reset()
      state = RideState()
      finishedRideID = nil
      lastSampleAt = nil
      mirrorToWatch()
   }

   // MARK: - Discarding

   /// Erases a ride that never went anywhere: no history row, no HealthKit
   /// workout, no summary full of zeros. The rider lands back on idle, exactly
   /// as they do when cancelling during GPS acquisition.
   ///
   /// Runs before finalization is scheduled, so no export can be in flight for
   /// this ride. An export still running for an *earlier* ride is left alone; it
   /// stamps nothing because `finalizeRide` only publishes into a finished phase.
   private func discardRide(reason: RideRetentionPolicy.DiscardReason) {
      rideStorageManager?.discardActiveRide(reason: reason)
      returnToIdle()

      DebugPrint(mode: .sessionLifecycle, "Ride discarded (\(reason.rawValue))")
   }

   // MARK: - Persistence

   /// Commits pending ride data. Called on pause and when the scene leaves the
   /// foreground so a force-quit or a dead battery cannot swallow the ride.
   func flushPendingWork() {
      guard let rideStorageManager else { return }

      rideStorageManager.flush()
      state.hasStorageFailure = rideStorageManager.hasFailure
   }

   // MARK: - Finalization

   private func finalizeRide() async {
      guard let commit = rideFinalizer.commit(state) else { return }

      state.hasStorageFailure = commit.hasStorageFailure
      finishedRideID = commit.ride?.persistentModelID

      guard let finishedRide = commit.ride, rideFinalizer.exportsToHealth else { return }

      state.healthKitExport = .exporting
      let export = await rideFinalizer.export(finishedRide)
      state.hasStorageFailure = export.hasStorageFailure

      // The rider may already have started over; never stamp a new ride's state.
      guard state.phase == .finished else { return }
      state.healthKitExport = export.status
   }

   private func requestHealthAuthorization() {
      guard rideFinalizer.exportsToHealth else { return }

      let finalizer = rideFinalizer

      authorizationTask?.cancel()
      authorizationTask = Task {
         await finalizer.requestHealthAuthorization()
      }
   }

   // MARK: - Streams

   private func startLocationStream() {
      let stream = locationManager.startUpdates()

      locationTask = Task { [weak self] in
         for await event in stream {
            guard let self else { return }
            self.handle(event)
         }
      }
   }

   private func startClock() {
      clockTask = Task { [weak self] in
         while !Task.isCancelled {
            do {
               try await Task.sleep(for: .seconds(1))
            } catch {
               return
            }

            guard let self else { return }
            self.tick()
         }
      }
   }

   private func stopStreams() {
      locationTask?.cancel()
      locationTask = nil

      clockTask?.cancel()
      clockTask = nil

      locationManager.stopUpdates()

      // Guidance is driven by this stream, so it can never outlive it — nor can
      // the audio session it holds while speaking.
      routeGuidanceManager?.stop()
   }

   // MARK: - Event Handling

   private func handle(_ event: RideLocationManager.Event) {
      switch event {
         case .issue(let issue):
            state.locationIssue = issue
            DebugPrint(mode: .locationFiltering, "Location issue: \(issue.rawValue)")

         case .location(let location):
            state.locationIssue = nil
            ingest(location)
      }
   }

   private func ingest(_ location: CLLocation) {
      guard state.phase.acceptsTelemetry else { return }

      let outcome = telemetryEngine.ingest(location)
      publishTelemetry()

      switch outcome {
         case .acquiredFix, .reseeded:
            beginRecordingIfNeeded()
            appendRoutePoint(location)

         case .accepted:
            lastSampleAt = .now
            appendRoutePoint(location)
            routeGuidanceManager?.follow(location, state: state)
            persist(location)

         case .rejected(let reason):
            DebugPrint(
               mode: .locationFiltering,
               limit: 50,
               "Rejected sample (\(reason.rawValue)) accuracy \(location.horizontalAccuracy)"
            )
      }
   }

   private func beginRecordingIfNeeded() {
      lastSampleAt = .now
      guard state.phase == .acquiringGPS else { return }

      let startDate = Date.now
      state.phase = .recording
      state.startDate = startDate

      rideStorageManager?.beginRide(startDate: startDate)
      state.hasStorageFailure = rideStorageManager?.hasFailure ?? false
      mirrorToWatch()

      DebugPrint(mode: .sessionLifecycle, "GPS fix acquired, recording started")
   }

   private func persist(_ location: CLLocation) {
      guard state.phase == .recording, let rideStorageManager else { return }

      let draft = RideSampleDraft(
         timestamp: location.timestamp,
         latitude: location.coordinate.latitude,
         longitude: location.coordinate.longitude,
         altitude: state.altitude ?? location.altitude,
         speed: state.speed,
         distance: state.distance,
         grade: state.grade,
         course: state.course
      )

      rideStorageManager.append(draft, totals: state)
      state.hasStorageFailure = rideStorageManager.hasFailure
   }

   // MARK: - Route

   private func appendRoutePoint(_ location: CLLocation) {
      guard state.phase == .recording else { return }
      rideRouteRecorder.append(location.coordinate)
   }

   // MARK: - Clock

   private func tick() {
      // Runs in every active phase, unlike the rest of the tick: a paused rider
      // whose Watch dropped off must not keep a frozen pulse on screen.
      expireStaleHeartRate()

      guard state.phase == .recording else { return }

      refreshElapsedTime()
      expireStaleSpeed()
      mirrorToWatch()
   }

   private func refreshElapsedTime() {
      guard let startDate = state.startDate else { return }

      state.elapsedTime = rideClock.elapsed(
         since: startDate,
         at: state.endDate ?? .now
      )
   }

   /// A stopped rider must not stare at the speed they were doing ten seconds ago.
   private func expireStaleSpeed() {
      guard let lastSampleAt,
            Date.now.timeIntervalSince(lastSampleAt) > sampleStalenessWindow,
            state.speed > 0
      else { return }

      telemetryEngine.markSpeedStale()
      publishTelemetry()
   }

   // MARK: - Watch Link

   /// Opens the wrist link for the life of the app.
   ///
   /// Not tied to a ride: START has to work from the wrist while the phone sits
   /// idle in a pocket, so this stream outlives every session and `stopStreams()`
   /// deliberately leaves it alone.
   func activateWatchLink() {
      guard let rideWatchManager else { return }

      watchLinkTask?.cancel()
      let events = rideWatchManager.activate()

      watchLinkTask = Task { [weak self] in
         for await event in events {
            guard let self else { return }
            self.handle(event)
         }
      }
   }

   private func handle(_ event: RideWatchManager.Event) {
      switch event {
         case .heartRate(let beatsPerMinute):
            state.heartRate = beatsPerMinute
            lastHeartRateAt = beatsPerMinute == nil ? nil : .now

         case .command(let request, let acknowledgement):
            apply(request, acknowledgement: acknowledgement)
      }
   }

   /// Drops a pulse the wrist stopped sending.
   ///
   /// The Watch says so explicitly when it stops sensing, but that message needs
   /// reachability. This covers the case where it never arrived.
   private func expireStaleHeartRate() {
      guard state.heartRate != nil,
            let lastHeartRateAt,
            Date.now.timeIntervalSince(lastHeartRateAt) > heartRateStalenessWindow
      else { return }

      state.heartRate = nil
      self.lastHeartRateAt = nil

      DebugPrint(mode: .sensors, "Heart rate expired; wrist stopped reporting")
   }

   /// Judges a remote command, then acts through the same lifecycle methods the
   /// phone's own buttons use.
   ///
   /// Every one of those methods already guards its phase, so a command that
   /// arrives twice — a live send and a queued transfer racing each other — costs
   /// nothing. The validator exists only to tell the rider *why* nothing happened.
   private func apply(
      _ request: RideRemoteCommandRequest,
      acknowledgement: RideRemoteCommandAcknowledgement
   ) {
      let outcome = RideRemoteCommandValidator.evaluate(request, phase: state.phase)

      if outcome == .accepted {
         switch request.command {
            case .start: start()
            case .pause: pause()
            case .resume: resume()
            case .end: end()
         }
      }

      acknowledgement(outcome, phase: state.phase)

      DebugPrint(
         mode: .sessionLifecycle,
         "Remote \(request.command.rawValue): \(outcome.rawValue), now \(state.phase.rawValue)"
      )
   }

   private func mirrorToWatch() {
      rideWatchManager?.publish(RideWatchMetricsSnapshot(state: state))
   }

   // MARK: - Publishing

   private func publishTelemetry() {
      state.speed = telemetryEngine.speed
      state.averageSpeed = telemetryEngine.averageSpeed
      state.maximumSpeed = telemetryEngine.maximumSpeed
      state.isMoving = telemetryEngine.isMoving
      state.distance = telemetryEngine.distance
      state.movingTime = telemetryEngine.movingTime
      state.stoppedTime = telemetryEngine.stoppedTime
      state.altitude = telemetryEngine.altitude
      state.elevationGain = telemetryEngine.elevationGain
      state.elevationLoss = telemetryEngine.elevationLoss
      state.grade = telemetryEngine.grade
      state.course = telemetryEngine.course
      state.horizontalAccuracy = telemetryEngine.horizontalAccuracy
      state.hasGPSFix = telemetryEngine.hasFix
   }
}
