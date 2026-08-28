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
         tile("DISTANCE", totals.distance, unit: totals.distanceUnit, id: "distance", alignment: .trailing)
         tile("RIDE TIME", totals.rideTime, id: "rideTime", alignment: .leading)
         tile("MOVING TIME", totals.movingTime, alignment: .trailing)
         tile("AVG SPEED", totals.averageSpeed, unit: totals.speedUnit, alignment: .leading)
         tile("MAX SPEED", totals.maximumSpeed, unit: totals.speedUnit, alignment: .trailing)
         tile("ELEV GAIN", totals.elevationGain, unit: totals.elevationUnit, alignment: .leading)
         tile("ELEV LOSS", totals.elevationLoss, unit: totals.elevationUnit, alignment: .trailing)

         // Radar totals appear only when the ride actually recorded passes,
         // so a radar-less ride shows exactly the grid it always did.
         if let vehicleCount = totals.vehicleCount {
            tile("VEHICLES", vehicleCount, id: "vehicles", alignment: .leading)
         }
         if let closestPass = totals.closestPass {
            tile("CLOSEST PASS", closestPass, id: "closestPass", alignment: .trailing)
         }
         if let maximumClosingSpeed = totals.maximumClosingSpeed {
            tile("MAX CLOSING", maximumClosingSpeed, unit: totals.speedUnit, id: "maxClosing", alignment: .leading)
         }
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
