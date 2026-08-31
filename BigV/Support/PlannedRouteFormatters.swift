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

   static func distance(_ meters: Double, system: RideUnitSystem = .current) -> String {
      "\(RideFormatters.distance(meters, system: system)) \(system.distanceUnit)"
   }

   // MARK: - Travel Time

   static func travelTime(_ seconds: TimeInterval) -> String {
      let minutes = Int((max(0, seconds) / 60).rounded())

      guard minutes >= 60 else { return "\(max(1, minutes)) min" }

      let hours = minutes / 60
      let remainder = minutes % 60

      return remainder == 0 ? "\(hours) hr" : "\(hours) hr \(remainder) min"
   }

   // MARK: - Elevation

   /// Climb figures live here so the route preview and the climb page can
   /// never drift in how a gain or a grade reads.

   static func elevationGain(_ meters: Double, system: RideUnitSystem = .current) -> String {
      "\(RideFormatters.elevationGain(meters, system: system)) \(system.elevationUnit)"
   }

   /// "+853 FT · 2 climbs" — the candidate row's one-line elevation story.
   static func climbSummary(
      ascent: Double,
      climbCount: Int,
      system: RideUnitSystem = .current
   ) -> String {
      let gain = elevationGain(ascent, system: system)
      guard climbCount > 0 else { return gain }
      return "\(gain) · \(climbCount) \(climbCount == 1 ? "climb" : "climbs")"
   }

   /// A climb's length, in route units: "2.10 MI".
   static func climbLength(_ meters: Double, system: RideUnitSystem = .current) -> String {
      distance(meters, system: system)
   }

   /// "6.2%" — average grade for climb rows and chips.
   static func averageGrade(_ percent: Double) -> String {
      "\(percent.formatted(.number.precision(.fractionLength(1))))%"
   }

   /// A climb-scale distance split into numeral and unit, so headline tiles
   /// can set them in their own type.
   ///
   /// Adaptive on the same thresholds as `RouteGuidanceFormatters.turnDistance`:
   /// a climb is approached like a turn, in feet or meters when it is close and
   /// in miles or kilometers when it is not.
   static func climbDistanceComponents(
      _ meters: Double,
      system: RideUnitSystem = .current
   ) -> (value: String, unit: String) {
      let clamped = max(0, meters)

      guard system == .imperial else {
         guard clamped >= 950 else {
            return ("\(Int((clamped / 10).rounded() * 10))", "M")
         }
         let kilometers = clamped / 1_000
         return (
            kilometers.formatted(.number.precision(.fractionLength(kilometers < 10 ? 1 : 0))),
            "KM"
         )
      }

      guard clamped >= 300 else {
         return ("\(Int((clamped / 0.3048 / 10).rounded() * 10))", "FT")
      }

      let miles = clamped / 1_609.344
      return (
         miles.formatted(.number.precision(.fractionLength(miles < 10 ? 1 : 0))),
         "MI"
      )
   }
}
