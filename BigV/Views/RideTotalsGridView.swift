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
         tile("DISTANCE", totals.distance, unit: RideFormatters.Unit.distance, id: "distance", alignment: .trailing)
         tile("RIDE TIME", totals.rideTime, id: "rideTime", alignment: .leading)
         tile("MOVING TIME", totals.movingTime, alignment: .trailing)
         tile("AVG SPEED", totals.averageSpeed, unit: RideFormatters.Unit.speed, alignment: .leading)
         tile("MAX SPEED", totals.maximumSpeed, unit: RideFormatters.Unit.speed, alignment: .trailing)
         tile("ELEV GAIN", totals.elevationGain, unit: RideFormatters.Unit.elevation, alignment: .leading)
         tile("ELEV LOSS", totals.elevationLoss, unit: RideFormatters.Unit.elevation, alignment: .trailing)
      }
   }

   // MARK: - Tile

   private func tile(
      _ title: String,
      _ value: String,
      unit: String? = nil,
      id suffix: String? = nil,
      alignment: HorizontalAlignment
   ) -> RideMetricTile {
      RideMetricTile(
         title: title,
         value: value,
         unit: unit,
         identifier: suffix.flatMap(identifier),
         gutterAlignment: alignment
      )
   }

   private func identifier(_ suffix: String) -> String? {
      identifierPrefix.map { "\($0).\(suffix)" }
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      RideTotalsGridView(totals: RideTotals(state: RideState()))
         .padding()
   }
   .preferredColorScheme(.dark)
}
