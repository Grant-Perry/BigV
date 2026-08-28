//
//  RideWatchMetricsSnapshot+RideState.swift
//  BigV
//

import Foundation

extension RideWatchMetricsSnapshot {

   /// Projects the phone's ride state onto the wrist.
   ///
   /// One-way by design. The Watch reads this and renders it; nothing on the
   /// Watch reconstructs a `RideState`, because there is only ever one.
   init(state: RideState, capturedAt: Date = .now) {
      self.init(
         phase: state.phase,
         speed: state.speed,
         distance: state.distance,
         elapsedTime: state.elapsedTime,
         hasGPSFix: state.hasGPSFix,
         isMoving: state.isMoving,
         capturedAt: capturedAt
      )
   }
}
