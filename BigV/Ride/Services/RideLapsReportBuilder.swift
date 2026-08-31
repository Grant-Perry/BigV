//
//  RideLapsReportBuilder.swift
//  BigV
//

import Foundation

/// Projects a saved ride's laps and climb splits into display rows.
///
/// Kept beside `RideChartSeriesBuilder` rather than in a view model so the
/// summary and the history detail cannot drift apart on formatting.
enum RideLapsReportBuilder {

   /// The report for `ride`, or `nil` when it recorded neither laps nor climbs
   /// — the card earns its place or stays off the screen.
   static func report(for ride: Ride, system: RideUnitSystem = .current) -> RideLapsReport? {
      let laps = ride.laps.sorted { $0.index < $1.index }
      let climbs = ride.climbSplits.sorted { $0.index < $1.index }
      guard !laps.isEmpty || !climbs.isEmpty else { return nil }

      return RideLapsReport(
         lapRows: laps.map { row(for: $0, system: system) },
         climbRows: climbs.map { row(for: $0, system: system) },
         summaryText: summary(lapCount: laps.count, climbCount: climbs.count)
      )
   }

   // MARK: - Rows

   private static func row(for lap: RideLap, system: RideUnitSystem) -> RideLapsReport.Row {
      let speed = RideFormatters.speed(lap.averageSpeed, system: system)
      let gain = RideFormatters.elevationGain(lap.elevationGain, system: system)

      return RideLapsReport.Row(
         id: lap.index,
         badge: "LAP \(lap.index)",
         timeText: RideFormatters.duration(lap.duration),
         distanceText: "\(RideFormatters.distance(lap.distance, system: system)) \(system.distanceUnit)",
         detailText: "\(speed) \(system.speedUnit) · \(gain) \(system.elevationUnit)"
      )
   }

   private static func row(for split: RideClimbSplit, system: RideUnitSystem) -> RideLapsReport.Row {
      let gain = RideFormatters.elevationGain(split.elevationGain, system: system)
      let grade = RideFormatters.grade(split.averageGrade)
      let vam = RideFormatters.verticalSpeed(split.verticalSpeed)

      return RideLapsReport.Row(
         id: split.index,
         badge: split.category?.label ?? "CLIMB",
         timeText: RideFormatters.duration(split.duration),
         distanceText: "\(RideFormatters.distance(split.distance, system: system)) \(system.distanceUnit)",
         detailText: "\(gain) \(system.elevationUnit) @ \(grade)% · \(vam) VAM"
      )
   }

   // MARK: - Summary

   private static func summary(lapCount: Int, climbCount: Int) -> String {
      var parts: [String] = []
      if lapCount > 0 {
         parts.append(lapCount == 1 ? "1 LAP" : "\(lapCount) LAPS")
      }
      if climbCount > 0 {
         parts.append(climbCount == 1 ? "1 CLIMB" : "\(climbCount) CLIMBS")
      }
      return parts.joined(separator: " · ")
   }
}
