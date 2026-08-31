//
//  RideLap.swift
//  BigV
//

import Foundation
import SwiftData

/// One lap of a ride, cut by the LAP button, an auto-lap boundary, or ride end.
///
/// Stored denormalized — distance, duration and average speed are written at
/// the cut, not derived from samples later — because a lap is a fact about the
/// moment it was cut and must survive any future change to how samples are
/// kept.
@Model
final class RideLap {

   /// 1-based position in the ride, the number a rider says out loud.
   var index: Int = 0

   var startDate: Date = Date.distantPast
   var endDate: Date = Date.distantPast

   /// Ride distance at the lap's ends, in meters.
   var startDistance: Double = 0
   var endDistance: Double = 0

   /// Meters covered within the lap.
   var distance: Double = 0

   /// Seconds from cut to cut.
   var duration: TimeInterval = 0

   /// Meters climbed within the lap.
   var elevationGain: Double = 0

   /// Meters/second over the lap.
   var averageSpeed: Double = 0

   /// `RideLapTracker.Trigger` raw value — what cut this lap.
   var triggerRawValue: String = RideLapTracker.Trigger.manual.rawValue

   var ride: Ride?

   // MARK: - Initialization

   init(lap: RideLapTracker.Lap) {
      index = lap.index
      startDate = lap.startDate
      endDate = lap.endDate
      startDistance = lap.startDistance
      endDistance = lap.endDistance
      distance = lap.distance
      duration = lap.duration
      elevationGain = lap.elevationGain
      averageSpeed = lap.averageSpeed
      triggerRawValue = lap.trigger.rawValue
   }
}
