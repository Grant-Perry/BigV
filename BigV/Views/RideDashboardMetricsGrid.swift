//
//  RideDashboardMetricsGrid.swift
//  BigV
//

import SwiftUI

/// Dashboard metrics. Left column trails into the gutter.
///
/// Portrait runs two tall columns. Landscape runs three short ones, because the
/// cockpit there is wide and shallow and two columns of full-size tiles do not
/// fit above the drawer and the tab bar.
struct RideDashboardMetricsGrid: View {

   let rideViewModel: RideViewModel
   let routeGuidanceViewModel: RouteGuidanceViewModel
   var isCompact: Bool = false

   @Environment(RideClimbModel.self) private var rideClimbModel

   private var tileColumns: [GridItem] {
      Array(
         repeating: GridItem(.flexible(), spacing: 10),
         count: isCompact ? 3 : 2
      )
   }

   var body: some View {
      LazyVGrid(columns: tileColumns, spacing: 10) {
         tile(
            "DISTANCE",
            value: rideViewModel.distance,
            unit: rideViewModel.distanceUnit,
            identifier: "ride.tile.distance",
            gutterAlignment: .trailing
         )

         tile(
            "RIDE TIME",
            value: rideViewModel.rideTime,
            identifier: "ride.tile.rideTime"
         )

         chartableTile(
            "ELEV GAIN",
            value: rideViewModel.elevationGain,
            unit: rideViewModel.elevationUnit,
            metric: .elevation,
            gutterAlignment: .trailing
         )

         tile(
            "GRADE",
            value: rideViewModel.grade,
            unit: rideViewModel.gradeUnit
         )

         chartableTile(
            "AVG SPEED",
            value: rideViewModel.averageSpeed,
            unit: rideViewModel.speedUnit,
            metric: .speed,
            gutterAlignment: .trailing
         )

         chartableTile(
            "MAX SPEED",
            value: rideViewModel.maximumSpeed,
            unit: rideViewModel.speedUnit,
            metric: .speed
         )

         tile(
            "ALT",
            value: rideViewModel.altitude,
            unit: rideViewModel.elevationUnit,
            identifier: "ride.tile.altitude",
            gutterAlignment: .trailing
         )

         // Only a route with a profile can promise what is left to climb;
         // without one the slot stays empty rather than showing a dash forever.
         if let ascentRemaining = rideClimbModel.routeAscentRemainingText {
            tile(
               "ASC REMAINING",
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
               identifier: "ride.tile.toGo",
               gutterAlignment: .trailing
            )

            tile(
               "ETA",
               value: routeGuidanceViewModel.arrivalTime,
               identifier: "ride.tile.eta"
            )
         }
      }
   }

   private func tile(
      _ title: String,
      value: String,
      unit: String? = nil,
      identifier: String? = nil,
      gutterAlignment: HorizontalAlignment = .leading
   ) -> some View {
      RideMetricTile(
         title: title,
         value: value,
         unit: unit,
         identifier: identifier,
         gutterAlignment: gutterAlignment,
         isCompact: isCompact
      )
   }

   private func chartableTile(
      _ title: String,
      value: String,
      unit: String? = nil,
      metric: RideLiveMetric,
      identifier: String? = nil,
      gutterAlignment: HorizontalAlignment = .leading
   ) -> some View {
      RideMetricTile(
         title: title,
         value: value,
         unit: unit,
         identifier: identifier,
         gutterAlignment: gutterAlignment,
         action: { rideViewModel.selectMetric(metric) },
         isSelected: rideViewModel.selectedMetric == metric,
         isCompact: isCompact
      )
   }
}
