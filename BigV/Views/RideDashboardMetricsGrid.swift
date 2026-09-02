//
//  RideDashboardMetricsGrid.swift
//  BigV
//

import SwiftUI

/// Everything under the hero.
///
/// Portrait leads with distance and ride time at full size, the two totals a
/// rider asks about most, then runs the supporting figures three across —
/// climb, grade, altitude, then pulse, VAM and moving time, and whatever a
/// route adds (ascent left, to-go and ETA). AVG and MAX ride in the hero
/// there. Landscape has no corner chips, so it carries the whole set in
/// compact tiles.
struct RideDashboardMetricsGrid: View {

   enum Layout: Sendable {
      case portrait
      case landscape
   }

   let rideViewModel: RideViewModel
   let routeGuidanceViewModel: RouteGuidanceViewModel
   var layout: Layout = .portrait

   @Environment(RideClimbModel.self) private var rideClimbModel

   private var tileColumns: [GridItem] {
      Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
   }

   var body: some View {
      VStack(spacing: 10) {
         if layout == .portrait {
            HStack(spacing: 10) {
               RideMetricTile(
                  title: "DISTANCE",
                  value: rideViewModel.distance,
                  unit: rideViewModel.distanceUnit,
                  identifier: "ride.tile.distance",
                  gutterAlignment: .trailing
               )

               RideMetricTile(
                  title: "RIDE TIME",
                  value: rideViewModel.rideTime,
                  identifier: "ride.tile.rideTime",
                  gutterAlignment: .leading
               )
            }
         }

         LazyVGrid(columns: tileColumns, spacing: 10) {
            if layout == .landscape {
               tile(
                  "DISTANCE",
                  value: rideViewModel.distance,
                  unit: rideViewModel.distanceUnit,
                  identifier: "ride.tile.distance"
               )

               tile(
                  "RIDE TIME",
                  value: rideViewModel.rideTime,
                  identifier: "ride.tile.rideTime"
               )
            }

            chartableTile(
               "ELEV GAIN",
               value: rideViewModel.elevationGain,
               unit: rideViewModel.elevationUnit,
               metric: .elevation
            )

            tile(
               "GRADE",
               value: rideViewModel.grade,
               unit: rideViewModel.gradeUnit
            )

            if layout == .landscape {
               chartableTile(
                  "AVG SPEED",
                  value: rideViewModel.averageSpeed,
                  unit: rideViewModel.speedUnit,
                  metric: .speed
               )

               chartableTile(
                  "MAX SPEED",
                  value: rideViewModel.maximumSpeed,
                  unit: rideViewModel.speedUnit,
                  metric: .speed
               )
            }

            tile(
               "ALT",
               value: rideViewModel.altitude,
               unit: rideViewModel.elevationUnit,
               identifier: "ride.tile.altitude"
            )

            if rideViewModel.isHeartRateActive {
               RideHeartRateMetricTile(
                  value: rideViewModel.heartRate ?? RideFormatters.placeholder,
                  unit: rideViewModel.heartRateUnit,
                  beatsPerMinute: rideViewModel.heartRateBeatsPerMinute,
                  isSelected: rideViewModel.selectedMetric == .heartRate,
                  isCompact: true,
                  action: { rideViewModel.selectMetric(.heartRate) }
               )
            }

            // Effort, climb rate, and honest time: the row a climber reads.
            tile(
               "VAM",
               value: rideViewModel.verticalSpeed,
               unit: rideViewModel.verticalSpeedUnit,
               identifier: "ride.tile.vam"
            )

            tile(
               "MOVING",
               value: rideViewModel.movingTime,
               identifier: "ride.tile.movingTime"
            )

            // Only a route with a profile can promise what is left to climb;
            // without one the slot stays empty rather than showing a dash forever.
            if let ascentRemaining = rideClimbModel.routeAscentRemainingText {
               tile(
                  "ASC LEFT",
                  value: ascentRemaining,
                  unit: rideClimbModel.elevationUnit,
                  identifier: "ride.tile.ascentRemaining"
               )
            }

            if routeGuidanceViewModel.isActive {
               tile(
                  "TO GO",
                  value: routeGuidanceViewModel.distanceRemaining,
                  unit: routeGuidanceViewModel.distanceRemainingUnit,
                  identifier: "ride.tile.toGo"
               )

               tile(
                  "ETA",
                  value: routeGuidanceViewModel.arrivalTime,
                  identifier: "ride.tile.eta"
               )
            }
         }
      }
      .animation(.easeInOut(duration: 0.25), value: rideViewModel.isHeartRateActive)
   }

   private func tile(
      _ title: String,
      value: String,
      unit: String? = nil,
      identifier: String? = nil
   ) -> some View {
      RideMetricTile(
         title: title,
         value: value,
         unit: unit,
         identifier: identifier,
         isCompact: true
      )
   }

   private func chartableTile(
      _ title: String,
      value: String,
      unit: String? = nil,
      metric: RideLiveMetric,
      identifier: String? = nil
   ) -> some View {
      RideMetricTile(
         title: title,
         value: value,
         unit: unit,
         identifier: identifier,
         action: { rideViewModel.selectMetric(metric) },
         isSelected: rideViewModel.selectedMetric == metric,
         isCompact: true
      )
   }
}
