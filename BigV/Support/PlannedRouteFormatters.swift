//
//  PlannedRouteFormatters.swift
//  BigV
//

import Foundation

/// Converts planned-route figures into rider-facing strings.
///
/// Separate from `RideFormatters` because the units read differently here: a
/// route is chosen at a glance from a list, so it wants "18 min", not the running
/// clock format a live ride uses.
enum PlannedRouteFormatters {

   // MARK: - Distance

   static func distance(_ meters: Double) -> String {
      "\(RideFormatters.distance(meters)) \(RideFormatters.Unit.distance)"
   }

   // MARK: - Travel Time

   static func travelTime(_ seconds: TimeInterval) -> String {
      let minutes = Int((max(0, seconds) / 60).rounded())

      guard minutes >= 60 else { return "\(max(1, minutes)) min" }

      let hours = minutes / 60
      let remainder = minutes % 60

      return remainder == 0 ? "\(hours) hr" : "\(hours) hr \(remainder) min"
   }
}
