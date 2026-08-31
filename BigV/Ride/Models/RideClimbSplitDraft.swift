//
//  RideClimbSplitDraft.swift
//  BigV
//

import Foundation

/// One completed climb, measured and ready to persist.
///
/// Same role as `RideSampleDraft`: the climb domain measures, the session
/// validates the phase, storage writes. Carries the ride's own telemetry over
/// the climb — not the route profile's promises — so the split records what
/// the rider actually did.
nonisolated struct RideClimbSplitDraft: Sendable, Equatable {

   let startDate: Date
   let endDate: Date

   /// Ride distance at the base and at the crest, in meters.
   let startDistance: Double
   let endDistance: Double

   /// Meters gained over the climb.
   let elevationGain: Double

   /// Average grade over the climb, as a percentage.
   let averageGrade: Double

   /// `nil` when the effort never earned a category.
   let category: ClimbCategory?

   // MARK: - Derived

   var distance: Double { max(0, endDistance - startDistance) }

   var duration: TimeInterval { max(0, endDate.timeIntervalSince(startDate)) }

   var averageSpeed: Double {
      duration > 0 ? distance / duration : 0
   }
}
