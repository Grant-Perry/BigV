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
   private let rideHealthManager: RideHealthManager?
   private let rideRouteRecorder: RideRouteRecorder
   private let routeGuidanceManager: RouteGuidanceManager?
   private var telemetryEngine: RideTelemetryEngine

   private var locationTask: Task<Void, Never>?
   private var clockTask: Task<Void, Never>?
   private var finalizeTask: Task<Void, Never>?
   private var authorizationTask: Task<Void, Never>?

   private var pauseStartedAt: Date?
   private var pausedDuration: TimeInterval = 0
   private var lastSampleAt: Date?

   /// Displayed speed drops to zero when samples stop arriving for this long.
   private let sampleStalenessWindow: TimeInterval = 4

   // MARK: - Initialization

   /// Storage and Health are optional so previews and engine tests can build a
   /// session with no side effects.
   init(
      locationManager: RideLocationManager = RideLocationManager(),
      configuration: RideTelemetryEngine.Configuration = .default,
      rideStorageManager: RideStorageManager? = nil,
      rideHealthManager: RideHealthManager? = nil,
      rideRouteRecorder: RideRouteRecorder = RideRouteRecorder(),
      routeGuidanceManager: RouteGuidanceManager? = nil
   ) {
      self.locationManager = locationManager
      self.rideStorageManager = rideStorageManager
      self.rideHealthManager = rideHealthManager
      self.rideRouteRecorder = rideRouteRecorder
      self.routeGuidanceManager = routeGuidanceManager
      self.telemetryEngine = RideTelemetryEngine(configuration: configuration)
   }

   // MARK: - Lifecycle

   func start() {
      guard !state.phase.isActive else { return }

      telemetryEngine.reset()
      rideRouteRecorder.reset()
      state = RideState()
      finishedRideID = nil
      state.phase = .acquiringGPS
      pausedDuration = 0
      pauseStartedAt = nil
      lastSampleAt = nil

      ScreenAwakeService.setKeepAwake(true)
      startLocationStream()
      startClock()
      requestHealthAuthorization()

      DebugPrint(mode: .sessionLifecycle, "Ride start requested")
   }

   func pause() {
      guard state.phase == .recording else { return }

      pauseStartedAt = .now
      state.phase = .paused
      telemetryEngine.markSpeedStale()
      publishTelemetry()
      flushPendingWork()

      DebugPrint(mode: .sessionLifecycle, "Ride paused")
   }

   func resume() {
      guard state.phase == .paused else { return }

      if let pauseStartedAt {
         pausedDuration += Date.now.timeIntervalSince(pauseStartedAt)
      }
      pauseStartedAt = nil
      lastSampleAt = nil
      state.phase = .recording

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

      if let pauseStartedAt {
         pausedDuration += Date.now.timeIntervalSince(pauseStartedAt)
         self.pauseStartedAt = nil
      }

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
      state = RideState()
      finishedRideID = nil
      pausedDuration = 0
      pauseStartedAt = nil
      lastSampleAt = nil
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
      guard let rideStorageManager else { return }

      let finishedRide = rideStorageManager.finalizeRide(with: state)
      state.hasStorageFailure = rideStorageManager.hasFailure
      finishedRideID = finishedRide?.persistentModelID

      guard let finishedRide, let rideHealthManager else { return }

      state.healthKitExport = .exporting
      let outcome = await rideHealthManager.export(finishedRide)

      let status: RideHealthExportStatus
      switch outcome {
         case .saved(let identifier):
            rideStorageManager.linkHealthKitWorkout(identifier, to: finishedRide)
            status = .saved

         case .denied:
            status = .denied

         case .unavailable:
            status = .unavailable

         case .failed:
            status = .failed
      }

      state.hasStorageFailure = rideStorageManager.hasFailure

      // The rider may already have started over; never stamp a new ride's state.
      guard state.phase == .finished else { return }
      state.healthKitExport = status
   }

   private func requestHealthAuthorization() {
      guard let rideHealthManager else { return }

      authorizationTask?.cancel()
      authorizationTask = Task {
         await rideHealthManager.requestAuthorizationIfNeeded()
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
      guard state.phase == .recording else { return }

      refreshElapsedTime()
      expireStaleSpeed()
   }

   private func refreshElapsedTime() {
      guard let startDate = state.startDate else { return }

      let reference = state.endDate ?? .now
      var elapsed = reference.timeIntervalSince(startDate) - pausedDuration

      if let pauseStartedAt {
         elapsed -= reference.timeIntervalSince(pauseStartedAt)
      }

      state.elapsedTime = max(0, elapsed)
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
