//
//  RideClimbSplit.swift
//  BigV
//

import Foundation
import SwiftData

/// One completed climb of a ride — a lap the mountain cut.
///
/// Written when a planned climb crests or the live detector confirms a
/// freeride climb is over. Denormalized like `RideLap`, plus the two figures a
/// lap has no use for: the grade that made it a climb and the category it
/// earned.
@Model
final class RideClimbSplit {

   /// 1-based position among the ride's climbs.
   var index: Int = 0

   var startDate: Date = Date.distantPast
   var endDate: Date = Date.distantPast

   /// Ride distance at the base and the crest, in meters.
   var startDistance: Double = 0
   var endDistance: Double = 0

   /// Meters covered base to crest.
   var distance: Double = 0

   /// Seconds base to crest.
   var duration: TimeInterval = 0

   /// Meters gained over the climb.
   var elevationGain: Double = 0

   /// Meters/second up the climb.
   var averageSpeed: Double = 0

   /// Average grade over the climb, as a percentage.
   var averageGrade: Double = 0

   /// `ClimbCategory` raw value; `nil` when the effort earned none.
   var categoryRawValue: Int?

   var ride: Ride?

   // MARK: - Derived

   var category: ClimbCategory? {
      categoryRawValue.flatMap(ClimbCategory.init)
   }

   /// VAM over the split, in meters/hour — the figure its row leads with.
   var verticalSpeed: Double {
      duration > 0 ? elevationGain / duration * 3_600 : 0
   }

   // MARK: - Initialization

   init(index: Int, draft: RideClimbSplitDraft) {
      self.index = index
      startDate = draft.startDate
      endDate = draft.endDate
      startDistance = draft.startDistance
      endDistance = draft.endDistance
      distance = draft.distance
      duration = draft.duration
      elevationGain = draft.elevationGain
      averageSpeed = draft.averageSpeed
      averageGrade = draft.averageGrade
      categoryRawValue = draft.category?.rawValue
   }
}
