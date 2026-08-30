//
//  RideWatchWorkoutRelay.swift
//  BigV Watch App
//

import Foundation
import HealthKit

/// The only `HKWorkoutSessionDelegate` in BigV.
///
/// Same job as `RideWatchConnectivityRelay`: absorb a queue-hopping delegate and
/// yield `Sendable` values, so the manager above it is plain `async`/`await`.
///
/// Notably absent: any reference to `associatedWorkoutBuilder`. The Watch runs a
/// sensor session and saves nothing — see `RideWatchWorkoutManager`.
nonisolated final class RideWatchWorkoutRelay: NSObject, HKWorkoutSessionDelegate, @unchecked Sendable {

   // MARK: - Private Properties

   private let continuation: AsyncStream<RideWatchSensorEvent>.Continuation

   // MARK: - Initialization

   init(continuation: AsyncStream<RideWatchSensorEvent>.Continuation) {
      self.continuation = continuation
      super.init()
   }

   // MARK: - Session State

   /// Every transition is reported, not just the terminal ones. `.prepared` is
   /// the gate `startActivity(with:)` has to wait behind, and a session that
   /// never reaches it is the difference between a working Start and a rider
   /// looking at the clock face.
   func workoutSession(
      _ workoutSession: HKWorkoutSession,
      didChangeTo toState: HKWorkoutSessionState,
      from fromState: HKWorkoutSessionState,
      date: Date
   ) {
      switch toState {
         case .prepared:
            continuation.yield(.prepared)

         case .running:
            continuation.yield(.running)

         case .paused:
            continuation.yield(.paused)

         case .ended, .stopped:
            continuation.yield(.ended)

         case .notStarted:
            break

         @unknown default:
            break
      }
   }

   func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
      continuation.yield(.failed(error.localizedDescription))
   }

   // MARK: - Teardown

   func finish() {
      continuation.finish()
   }
}
