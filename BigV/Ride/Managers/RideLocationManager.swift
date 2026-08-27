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
   func startUpdates() -> AsyncStream<Event> {
      stopUpdates()
      requestAuthorizationIfNeeded()

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
      updatesTask?.cancel()
      updatesTask = nil

      continuation?.finish()
      continuation = nil

      backgroundSession?.invalidate()
      backgroundSession = nil

      DebugPrint(mode: .sessionLifecycle, "Location updates stopped")
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
               continuation.yield(.issue(.temporarilyUnavailable))
               continue
            }

            guard let location = update.location else { continue }

            beginBackgroundSessionIfNeeded()
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
   /// Deferred until a fix actually arrives: `requestWhenInUseAuthorization()`
   /// returns while the prompt is still on screen, so creating the session in
   /// `startUpdates()` would race a first-launch grant. A delivered location is
   /// proof that authorization was granted.
   private func beginBackgroundSessionIfNeeded() {
      guard backgroundSession == nil else { return }

      backgroundSession = CLBackgroundActivitySession()
      DebugPrint(mode: .sessionLifecycle, "Background activity session started")
   }
}
