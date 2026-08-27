//
//  RideTotalsGridView.swift
//  BigV
//

import SwiftUI

/// The tile grid of ride totals, shared by the post-ride summary and a saved ride.
struct RideTotalsGridView: View {

   let totals: RideTotals
   var identifierPrefix: String?

   private let tileColumns = [
      GridItem(.flexible(), spacing: 10),
      GridItem(.flexible(), spacing: 10)
   ]

   var body: some View {
      LazyVGrid(columns: tileColumns, spacing: 10) {
         RideMetricTile(
            title: "DISTANCE",
            value: totals.distance,
            unit: RideFormatters.Unit.distance,
            identifier: identifier("distance")
         )

         RideMetricTile(
            title: "RIDE TIME",
            value: totals.rideTime,
            identifier: identifier("rideTime")
         )

         RideMetricTile(
            title: "MOVING TIME",
            value: totals.movingTime
         )

         RideMetricTile(
            title: "AVG SPEED",
            value: totals.averageSpeed,
            unit: RideFormatters.Unit.speed
         )

         RideMetricTile(
            title: "MAX SPEED",
            value: totals.maximumSpeed,
            unit: RideFormatters.Unit.speed
         )

         RideMetricTile(
            title: "ELEV GAIN",
            value: totals.elevationGain,
            unit: RideFormatters.Unit.elevation
         )

         RideMetricTile(
            title: "ELEV LOSS",
            value: totals.elevationLoss,
            unit: RideFormatters.Unit.elevation
         )
      }
   }

   // MARK: - Identifiers

   private func identifier(_ suffix: String) -> String? {
      identifierPrefix.map { "\($0).\(suffix)" }
   }
}

#Preview {
   ZStack {
      Color.black
      RideTotalsGridView(totals: RideTotals(state: RideState()))
         .padding()
   }
   .preferredColorScheme(.dark)
}
