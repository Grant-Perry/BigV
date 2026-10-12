//
//  RideLocationManager.swift
//  BigV
//

import CoreLocation
import Foundation

/// Delivers Core Location samples to the ride session as an async stream.
///
/// Owns authorization, the `CLLocationManager` behind the ride, and the
/// background activity session that keeps GPS alive while the phone is
/// mounted and the screen is off. The session exists exactly as long as a
/// ride's stream does, so the system's location indicator means one thing: a
/// ride is recording. It performs no ride math; filtering lives in
/// `RideTelemetryEngine`.
///
/// Deliberately not `CLLocationUpdate.liveUpdates`: that sequence pauses
/// itself once the phone looks stationary and only resumes when the motion
/// coprocessor notices movement, with no knob to turn it off. A bike computer
/// started at a kerb cannot be on a stream that decides for itself when the
/// ride began. `pausesLocationUpdatesAutomatically = false` is the whole point.
@MainActor
final class RideLocationManager {

   // MARK: - Events

   enum Event: Sendable {
      case location(CLLocation, accuracyLimited: Bool)
      case issue(RideLocationIssue)
   }

   // MARK: - Private Properties

   private let locationManager = CLLocationManager()
   private let relay = LocationRelay()
   private var relayTask: Task<Void, Never>?
   private var retryTask: Task<Void, Never>?
   private var stopDeliveryTask: Task<Void, Never>?
   private var backgroundSession: CLBackgroundActivitySession?
   private var continuation: AsyncStream<Event>.Continuation?

   /// Whether `startUpdatingLocation()` has been asked for and not stopped.
   private var isDelivering = false

   /// Whether delivery ended on a problem only the rider can fix, with the
   /// consumer stream still open waiting for `restartIfStalled`.
   private var isStalled = false

   /// Pause before re-opening delivery that failed, so a persistent error
   /// cannot spin.
   private static let retryBackoff: Duration = .seconds(3)

   /// When the receiver was last started. The first callback after
   /// `startUpdatingLocation()` routinely replays Core Location's cache; a fix
   /// stamped before this moment is that replay, not where the rider is.
   ///
   /// Judged against the start, not against the wall clock: a live fix that
   /// waited out a busy main actor is still the newest position there is,
   /// and dropping it for being old would leave the hero with nothing.
   private var deliveryStartedAt: Date?

   /// A fix computed a breath before `startUpdatingLocation()` is still now.
   private nonisolated static let cacheTolerance: TimeInterval = 1

   /// How long GPS stays up after a ride's stream ends. END then START on the
   /// same turn — a rider restarting mid-roll — must not power-cycle the
   /// receiver and hand the new ride a minute of Wi-Fi fixes while it relocks.
   private static let deliveryGrace: Duration = .seconds(3)

   init() {
      locationManager.delegate = relay
      locationManager.activityType = .fitness
      locationManager.desiredAccuracy = kCLLocationAccuracyBest
      locationManager.distanceFilter = kCLDistanceFilterNone
      locationManager.pausesLocationUpdatesAutomatically = false
      locationManager.showsBackgroundLocationIndicator = true

      let signals = relay.signals
      relayTask = Task { [weak self] in
         for await signal in signals {
            guard let self else { return }
            self.handle(signal)
         }
      }
   }

   // MARK: - Authorization

   var isAuthorized: Bool {
      switch locationManager.authorizationStatus {
         case .authorizedAlways, .authorizedWhenInUse: true
         default: false
      }
   }

   /// Whether a ride can bring GPS up with the app in the background.
   ///
   /// When In Use only delivers to an app that is in front, or that carried a
   /// stream out of the foreground. A START from the wrist with the phone
   /// locked in a pocket is neither, so it needs Always.
   var canBeginFromBackground: Bool {
      locationManager.authorizationStatus == .authorizedAlways
   }

   func requestAuthorizationIfNeeded() {
      guard locationManager.authorizationStatus == .notDetermined else { return }
      locationManager.requestWhenInUseAuthorization()
   }

   /// Asks to step up from When In Use to Always. Foreground only; the system
   /// shows the upgrade once per install, so this is called when a paired
   /// Watch gives the rider a reason to say yes.
   func requestAlwaysAuthorizationIfNeeded() {
      guard locationManager.authorizationStatus == .authorizedWhenInUse else { return }
      locationManager.requestAlwaysAuthorization()
   }

   // MARK: - Updates

   /// Starts location delivery. Any previous stream is torn down first.
   ///
   /// The background activity session lives exactly as long as a ride's
   /// stream. Nothing holds one between rides: the system keeps a session's
   /// indicator up after the rider force quits the app and does not relaunch
   /// the app to end it, so a session with no ride behind it would sit in the
   /// Dynamic Island until the next launch.
   func startUpdates() -> AsyncStream<Event> {
      stopDeliveryTask?.cancel()
      stopDeliveryTask = nil
      finishStream()
      requestAuthorizationIfNeeded()

      let (stream, continuation) = AsyncStream<Event>.makeStream(
         bufferingPolicy: .bufferingNewest(16)
      )
      self.continuation = continuation

      // Not yet authorized: delivery begins from the authorization callback.
      // Already delivering from a ride that ended moments ago: keep it warm.
      RideFixLogStore.shared.note(
         "receiver auth=\(locationManager.authorizationStatus.rawValue) accuracyAuth=\(locationManager.accuracyAuthorization.rawValue) (0=full 1=reduced)"
      )
      if isAuthorized {
         beginBackgroundSessionIfNeeded()
         let warmReuse = isDelivering
         RideFixLogStore.shared.note(
            "receiver startUpdates manager=\(ObjectIdentifier(self).hashValue) branch=\(warmReuse ? "warm-reuse(isDelivering)" : "cold-start")"
         )
         if !warmReuse {
            beginDelivery()
         }
      } else {
         RideFixLogStore.shared.note(
            "receiver startUpdates manager=\(ObjectIdentifier(self).hashValue) branch=unauthorized-deferred"
         )
      }

      DebugPrint(mode: .sessionLifecycle, "Location updates started")
      return stream
   }

   func stopUpdates() {
      finishStream()
      endBackgroundSession()

      // Fixes that land in the grace find no stream and are dropped.
      stopDeliveryTask?.cancel()
      stopDeliveryTask = Task { [weak self] in
         do {
            try await Task.sleep(for: Self.deliveryGrace)
         } catch {
            return
         }
         guard let self, self.continuation == nil else { return }
         self.endDelivery()
      }

      DebugPrint(mode: .sessionLifecycle, "Location updates stopped")
   }

   /// Re-opens delivery that ended because the rider had to change something.
   /// Called when the scene comes forward and when authorization changes. A
   /// no-op unless a ride's stream is open and stalled.
   func restartIfStalled() {
      guard isStalled, continuation != nil, isAuthorized else { return }

      beginBackgroundSessionIfNeeded()
      beginDelivery()
      DebugPrint(mode: .sessionLifecycle, "Location updates restarted after rider action")
   }

   // MARK: - Delivery

   private func beginDelivery() {
      retryTask?.cancel()
      retryTask = nil
      isStalled = false

      // Requires the `location` background mode, which Info.plist declares.
      // With When In Use this carries a stream begun in front out of the
      // foreground; with Always it lets a wrist START bring GPS up pocketed.
      locationManager.allowsBackgroundLocationUpdates = true
      deliveryStartedAt = .now
      locationManager.startUpdatingLocation()
      isDelivering = true
      RideFixLogStore.shared.note("CL startUpdatingLocation manager=\(ObjectIdentifier(self).hashValue)")
   }

   /// Whether a fix predates the current receiver start, meaning Core
   /// Location replayed it from cache rather than measuring it.
   nonisolated static func isReplayedFromCache(
      _ timestamp: Date,
      deliveryStartedAt: Date?
   ) -> Bool {
      guard let deliveryStartedAt else { return false }
      return timestamp < deliveryStartedAt.addingTimeInterval(-cacheTolerance)
   }

   private func endDelivery() {
      guard isDelivering else { return }
      locationManager.stopUpdatingLocation()
      isDelivering = false
      RideFixLogStore.shared.note("CL stopUpdatingLocation manager=\(ObjectIdentifier(self).hashValue)")
   }

   /// Closes the consumer's stream without touching delivery; `stopUpdates`
   /// and `startUpdates` decide what happens to the receiver.
   private func finishStream() {
      retryTask?.cancel()
      retryTask = nil
      isStalled = false

      continuation?.finish()
      continuation = nil
   }

   /// Stops and restarts delivery after a backoff. Only for errors that are
   /// not the rider's to fix; those stall instead.
   private func scheduleRetry() {
      endDelivery()
      retryTask?.cancel()
      retryTask = Task { [weak self] in
         do {
            try await Task.sleep(for: Self.retryBackoff)
         } catch {
            return
         }
         guard let self, self.continuation != nil, self.isAuthorized else { return }
         self.beginDelivery()
      }
   }

   // MARK: - Signals

   private func handle(_ signal: LocationRelay.Signal) {
      switch signal {
         case .locations(let locations):
            deliver(locations)

         case .failed(let error):
            handleFailure(error)

         case .authorizationChanged:
            handleAuthorizationChange()

         case .pausedBySystem:
            // Cannot happen with automatic pausing off; if it ever does, say so
            // loudly and get the stream back rather than sit at 0.0.
            DebugPrint(mode: .sessionLifecycle, "Location delivery paused by the system; resuming")
            if continuation != nil, isAuthorized {
               beginDelivery()
            }
      }
   }

   private func deliver(_ locations: [CLLocation]) {
      guard let continuation else { return }

      let accuracyLimited = locationManager.accuracyAuthorization == .reducedAccuracy

      for location in locations {
         guard !Self.isReplayedFromCache(location.timestamp, deliveryStartedAt: deliveryStartedAt) else {
            DebugPrint(
               mode: .locationFiltering,
               "Dropped cached fix \(Int(Date.now.timeIntervalSince(location.timestamp))) s old, accuracy \(Int(location.horizontalAccuracy)) m"
            )
            continue
         }

         beginBackgroundSessionIfNeeded()
         continuation.yield(.location(location, accuracyLimited: accuracyLimited))
      }
   }

   private func handleFailure(_ error: any Error) {
      guard let continuation else { return }

      switch (error as? CLError)?.code {
         case .locationUnknown:
            // Core Location keeps trying on its own; just say there is no fix.
            continuation.yield(.issue(.temporarilyUnavailable))

         case .denied:
            // Delivery has already stopped. Both Location Services off and a
            // denied app arrive as this code; the authorization status tells
            // them apart only when the app itself was denied.
            isDelivering = false
            isStalled = true
            let issue: RideLocationIssue = locationManager.authorizationStatus == .denied
               ? .authorizationDenied
               : .servicesDisabled
            continuation.yield(.issue(issue))

         default:
            DebugPrint(mode: .sessionLifecycle, "Location stream failed: \(error.localizedDescription)")
            continuation.yield(.issue(.failed))
            scheduleRetry()
      }
   }

   private func handleAuthorizationChange() {
      guard continuation != nil else { return }

      if isStalled {
         restartIfStalled()
         return
      }

      // A ride started before the first grant lands here with no delivery.
      if isAuthorized, !isDelivering {
         beginBackgroundSessionIfNeeded()
         beginDelivery()
      }
   }

   // MARK: - Background Session

   /// Keeps location running while mounted with the screen asleep.
   ///
   /// `CLBackgroundActivitySession` is what keeps a When In Use stream alive
   /// while the phone is locked. Create it as soon as we already have
   /// when-in-use; a first-launch prompt still waits for `isAuthorized` so we
   /// do not race the grant.
   private func beginBackgroundSessionIfNeeded() {
      guard backgroundSession == nil, isAuthorized else { return }

      backgroundSession = CLBackgroundActivitySession()
      DebugPrint(mode: .sessionLifecycle, "Background activity session started")
   }

   private func endBackgroundSession() {
      guard let backgroundSession else { return }

      backgroundSession.invalidate()
      self.backgroundSession = nil
      DebugPrint(mode: .sessionLifecycle, "Background activity session ended")
   }
}

// MARK: - Location Relay

/// Turns delegate callbacks into an ordered stream the main actor consumes,
/// without making the manager an `NSObject` or assuming which thread Core
/// Location called back on.
private final class LocationRelay: NSObject, CLLocationManagerDelegate, Sendable {

   enum Signal: Sendable {
      case locations([CLLocation])
      case failed(any Error)
      case authorizationChanged
      case pausedBySystem
   }

   let signals: AsyncStream<Signal>
   private let continuation: AsyncStream<Signal>.Continuation

   override init() {
      (signals, continuation) = AsyncStream<Signal>.makeStream(bufferingPolicy: .unbounded)
      super.init()
   }

   nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
      continuation.yield(.locations(locations))
   }

   nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
      continuation.yield(.failed(error))
   }

   nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
      continuation.yield(.authorizationChanged)
   }

   nonisolated func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
      continuation.yield(.pausedBySystem)
   }
}
