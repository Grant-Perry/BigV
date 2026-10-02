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
/// off. It performs no ride math; filtering lives in `RideTelemetryEngine`.
@MainActor
final class RideLocationManager {

   // MARK: - Events

   enum Event: Sendable {
      case location(CLLocation)
      case issue(RideLocationIssue)
   }

   // MARK: - Private Properties

   private let authorizationManager = CLLocationManager()
   private var backgroundSession: CLBackgroundActivitySession?
   private var updatesTask: Task<Void, Never>?
   private var continuation: AsyncStream<Event>.Continuation?

   /// Whether the held session should outlive the ride stream so a START from
   /// the wrist can bring GPS up with the phone still in a pocket.
   private var isArmedForRemoteStart = false

   /// Whether the held session was opened while the app was in the foreground.
   /// One opened from the background may be a dead object, so it is replaced
   /// the next time the app is in front.
   private var sessionBeganInForeground = false

   // MARK: - Authorization

   var isAuthorized: Bool {
      switch authorizationManager.authorizationStatus {
         case .authorizedAlways, .authorizedWhenInUse: true
         default: false
      }
   }

   func requestAuthorizationIfNeeded() {
      guard authorizationManager.authorizationStatus == .notDetermined else { return }
      authorizationManager.requestWhenInUseAuthorization()
   }

   // MARK: - Updates

   /// Starts location delivery. Any previous stream is torn down first.
   ///
   /// The background session is reused, never recycled, here: a START that
   /// arrives from the wrist with the phone locked is running in the
   /// background, and the only session that can keep GPS alive from there is
   /// one that was already open. See `armForRemoteStart(isInForeground:)`.
   func startUpdates(isInForeground: Bool) -> AsyncStream<Event> {
      stopStream()
      requestAuthorizationIfNeeded()

      if isAuthorized {
         beginBackgroundSessionIfNeeded(isInForeground: isInForeground)
      }

      let (stream, continuation) = AsyncStream<Event>.makeStream(
         bufferingPolicy: .bufferingNewest(16)
      )
      self.continuation = continuation

      updatesTask = Task { [weak self] in
         await self?.consumeUpdates(yielding: continuation)
      }

      DebugPrint(mode: .sessionLifecycle, "Location updates started")
      return stream
   }

   func stopUpdates() {
      stopStream()

      if !isArmedForRemoteStart {
         endBackgroundSession()
      }

      DebugPrint(mode: .sessionLifecycle, "Location updates stopped")
   }

   private func stopStream() {
      updatesTask?.cancel()
      updatesTask = nil

      continuation?.finish()
      continuation = nil
   }

   // MARK: - Remote Start

   /// Holds a background session open between rides so START from the wrist
   /// works with the phone in a pocket.
   ///
   /// Core Location only lets a background activity session *begin* while the
   /// app is in the foreground; from the background an app can rejoin a
   /// session it already holds, never open a new one. A session first created
   /// inside a Watch command therefore does nothing when the phone is locked:
   /// one fix may land in the wake window, then the stream goes quiet and the
   /// cockpit sits at 0.00 with the elevation of that single fix. Arming while
   /// the rider still has the app in front is what makes the wrist START work.
   ///
   /// Calling this from the background is safe: it either rejoins a session
   /// this app held before being terminated or quietly does nothing.
   func armForRemoteStart(isInForeground: Bool) {
      isArmedForRemoteStart = true
      guard isAuthorized else { return }

      // A session opened from the background is replaced as soon as the app
      // is in front, where a fresh one is guaranteed to take.
      if isInForeground, backgroundSession != nil, !sessionBeganInForeground {
         endBackgroundSession()
      }

      beginBackgroundSessionIfNeeded(isInForeground: isInForeground)
   }

   /// Releases the held session once no ride needs it. No Watch, no reason
   /// to show the rider a location indicator between rides.
   func disarmRemoteStart() {
      isArmedForRemoteStart = false
      guard updatesTask == nil else { return }
      endBackgroundSession()
   }

   // MARK: - Consumption

   private func consumeUpdates(yielding continuation: AsyncStream<Event>.Continuation) async {
      do {
         for try await update in CLLocationUpdate.liveUpdates(.fitness) {
            if Task.isCancelled { break }

            if update.authorizationDeniedGlobally {
               continuation.yield(.issue(.servicesDisabled))
               break
            }

            if update.authorizationDenied {
               continuation.yield(.issue(.authorizationDenied))
               break
            }

            if update.locationUnavailable {
               if isAuthorized {
                  beginBackgroundSessionIfNeeded(isInForeground: false)
               }
               continuation.yield(.issue(.temporarilyUnavailable))
               continue
            }

            guard let location = update.location else { continue }

            beginBackgroundSessionIfNeeded(isInForeground: false)
            continuation.yield(.location(location))
         }
      } catch {
         DebugPrint(mode: .sessionLifecycle, "Location stream failed: \(error.localizedDescription)")
         continuation.yield(.issue(.failed))
      }

      continuation.finish()
   }

   // MARK: - Background Session

   /// Keeps location running while mounted with the screen asleep.
   ///
   /// `CLBackgroundActivitySession` is what keeps `liveUpdates` alive while
   /// the phone is locked. Create it as soon as we already have when-in-use;
   /// a first-launch prompt still waits for `isAuthorized` so we do not
   /// race the grant.
   private func beginBackgroundSessionIfNeeded(isInForeground: Bool) {
      guard backgroundSession == nil else { return }

      backgroundSession = CLBackgroundActivitySession()
      sessionBeganInForeground = isInForeground
      DebugPrint(
         mode: .sessionLifecycle,
         "Background activity session started (\(isInForeground ? "foreground" : "background"))"
      )
   }

   private func endBackgroundSession() {
      guard let backgroundSession else { return }

      backgroundSession.invalidate()
      self.backgroundSession = nil
      sessionBeganInForeground = false
      DebugPrint(mode: .sessionLifecycle, "Background activity session ended")
   }
}
