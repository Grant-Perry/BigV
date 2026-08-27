//
//  RideDashboardMetricsGrid.swift
//  BigV
//

import SwiftUI

/// Dashboard 2-column metrics. Left column trails into the gutter.
struct RideDashboardMetricsGrid: View {

   let rideViewModel: RideViewModel
   let routeGuidanceViewModel: RouteGuidanceViewModel

   private let tileColumns = [
      GridItem(.flexible(), spacing: 10),
      GridItem(.flexible(), spacing: 10)
   ]

   var body: some View {
      LazyVGrid(columns: tileColumns, spacing: 10) {
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

         RideMetricTile(
            title: "ELEV GAIN",
            value: rideViewModel.elevationGain,
            unit: rideViewModel.elevationUnit,
            gutterAlignment: .trailing
         )

         RideMetricTile(
            title: "GRADE",
            value: rideViewModel.grade,
            unit: rideViewModel.gradeUnit,
            gutterAlignment: .leading
         )

         RideMetricTile(
            title: "AVG SPEED",
            value: rideViewModel.averageSpeed,
            unit: rideViewModel.speedUnit,
            gutterAlignment: .trailing
         )

         RideMetricTile(
            title: "MAX SPEED",
            value: rideViewModel.maximumSpeed,
            unit: rideViewModel.speedUnit,
            gutterAlignment: .leading
         )

         if routeGuidanceViewModel.isActive {
            RideMetricTile(
               title: "TO GO",
               value: routeGuidanceViewModel.distanceRemaining,
               unit: routeGuidanceViewModel.distanceRemainingUnit,
               identifier: "ride.tile.toGo",
               gutterAlignment: .trailing
            )

            RideMetricTile(
               title: "ETA",
               value: routeGuidanceViewModel.arrivalTime,
               identifier: "ride.tile.eta",
               gutterAlignment: .leading
            )
         }
      }
   }
}
