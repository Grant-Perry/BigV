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

   func workoutSession(
      _ workoutSession: HKWorkoutSession,
      didChangeTo toState: HKWorkoutSessionState,
      from fromState: HKWorkoutSessionState,
      date: Date
   ) {
      switch toState {
         case .ended, .stopped:
            continuation.yield(.ended)

         default:
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
