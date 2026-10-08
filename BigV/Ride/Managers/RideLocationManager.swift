//
//  RideLocationManager.swift
//  BigV
//

import CoreLocation
import Foundation

/// Delivers Core Location samples to the ride session as an async stream.
///
/// Owns authorization, the live update sequence and the background activity
/// session that keeps GPS alive while the phone is mounted and the screen is
/// off. The session exists exactly as long as a ride's stream does, so the
/// system's location indicator means one thing: a ride is recording. It
/// performs no ride math; filtering lives in `RideTelemetryEngine`.
@MainActor
final class RideLocationManager {

   // MARK: - Events

   enum Event: Sendable {
      case location(CLLocation, accuracyLimited: Bool)
      case issue(RideLocationIssue)
   }

   // MARK: - Private Properties

   private let authorizationManager = CLLocationManager()
   private let authorizationObserver = AuthorizationObserver()
   private var backgroundSession: CLBackgroundActivitySession?
   private var updatesTask: Task<Void, Never>?
   private var continuation: AsyncStream<Event>.Continuation?

   /// Whether the live stream ended on a problem only the rider can fix, with
   /// the consumer stream still open waiting for `restartIfStalled`.
   private var isStalled = false

   /// Pause before re-opening a stream that failed, so a persistent error
   /// cannot spin.
   private static let retryBackoff: Duration = .seconds(3)

   init() {
      authorizationObserver.onChange = { [weak self] in
         self?.authorizationDidChange()
      }
      authorizationManager.delegate = authorizationObserver
   }

   // MARK: - Authorization

   var isAuthorized: Bool {
      switch authorizationManager.authorizationStatus {
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
      authorizationManager.authorizationStatus == .authorizedAlways
   }

   func requestAuthorizationIfNeeded() {
      guard authorizationManager.authorizationStatus == .notDetermined else { return }
      authorizationManager.requestWhenInUseAuthorization()
   }

   /// Asks to step up from When In Use to Always. Foreground only; the system
   /// shows the upgrade once per install, so this is called when a paired
   /// Watch gives the rider a reason to say yes.
   func requestAlwaysAuthorizationIfNeeded() {
      guard authorizationManager.authorizationStatus == .authorizedWhenInUse else { return }
      authorizationManager.requestAlwaysAuthorization()
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
      stopStream()
      requestAuthorizationIfNeeded()

      if isAuthorized {
         beginBackgroundSessionIfNeeded()
      }

      let (stream, continuation) = AsyncStream<Event>.makeStream(
         bufferingPolicy: .bufferingNewest(16)
      )
      self.continuation = continuation
      launchConsumer(yielding: continuation)

      DebugPrint(mode: .sessionLifecycle, "Location updates started")
      return stream
   }

   func stopUpdates() {
      stopStream()
      endBackgroundSession()
      DebugPrint(mode: .sessionLifecycle, "Location updates stopped")
   }

   /// Re-opens a stream that ended because the rider had to change something.
   /// Called when the scene comes forward and when authorization changes. A
   /// no-op unless a ride's stream is open and stalled.
   func restartIfStalled() {
      guard isStalled, let continuation, isAuthorized,
            CLLocationManager.locationServicesEnabled()
      else { return }

      beginBackgroundSessionIfNeeded()
      launchConsumer(yielding: continuation)
      DebugPrint(mode: .sessionLifecycle, "Location updates restarted after rider action")
   }

   private func launchConsumer(yielding continuation: AsyncStream<Event>.Continuation) {
      isStalled = false
      updatesTask?.cancel()
      updatesTask = Task { [weak self] in
         await self?.consumeUpdates(yielding: continuation)
      }
   }

   private func authorizationDidChange() {
      restartIfStalled()
   }

   private func stopStream() {
      updatesTask?.cancel()
      updatesTask = nil
      isStalled = false

      continuation?.finish()
      continuation = nil
   }

   // MARK: - Consumption

   private func consumeUpdates(yielding continuation: AsyncStream<Event>.Continuation) async {
      // A failed stream is re-opened after a short backoff; a stream stopped by
      // a rider-fixable issue stays stalled until `restartIfStalled`. Neither
      // finishes the consumer's stream — only `stopStream` does.
      while !Task.isCancelled {
         do {
            for try await update in CLLocationUpdate.liveUpdates(.fitness) {
               if Task.isCancelled { return }

               if update.authorizationDeniedGlobally {
                  continuation.yield(.issue(.servicesDisabled))
                  isStalled = true
                  return
               }

               if update.authorizationDenied {
                  continuation.yield(.issue(.authorizationDenied))
                  isStalled = true
                  return
               }

               if update.locationUnavailable {
                  if isAuthorized {
                     beginBackgroundSessionIfNeeded()
                  }
                  continuation.yield(.issue(.temporarilyUnavailable))
                  continue
               }

               guard let location = update.location else { continue }

               beginBackgroundSessionIfNeeded()
               continuation.yield(.location(location, accuracyLimited: update.accuracyLimited))
            }
         } catch {
            DebugPrint(mode: .sessionLifecycle, "Location stream failed: \(error.localizedDescription)")
            continuation.yield(.issue(.failed))
         }

         if Task.isCancelled { return }

         do {
            try await Task.sleep(for: Self.retryBackoff)
         } catch {
            return
         }
      }
   }

   // MARK: - Background Session

   /// Keeps location running while mounted with the screen asleep.
   ///
   /// `CLBackgroundActivitySession` is what keeps `liveUpdates` alive while
   /// the phone is locked. Create it as soon as we already have when-in-use;
   /// a first-launch prompt still waits for `isAuthorized` so we do not
   /// race the grant.
   private func beginBackgroundSessionIfNeeded() {
      guard backgroundSession == nil else { return }

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

// MARK: - Authorization Observer

/// Forwards authorization changes without making the manager an `NSObject`.
private final class AuthorizationObserver: NSObject, CLLocationManagerDelegate, @unchecked Sendable {

   var onChange: (@MainActor () -> Void)?

   nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
      Task { @MainActor [weak self] in
         self?.onChange?()
      }
   }
}
