//
//  RideElevationCard.swift
//  BigV
//

import SwiftUI

/// The terrain the ride crossed: an altitude profile over distance, with the
/// gain, loss and the high and low points it explains.
struct RideElevationCard: View {

   let report: RideElevationReport

   var body: some View {
      VStack(alignment: .leading, spacing: 12) {
         RideDetailCardHeader(
            icon: "mountain.2.fill",
            tint: RideDashboardTheme.ice,
            title: "ELEVATION",
            detail: "\(report.gainText) / \(report.lossText) \(report.elevationUnit)"
         )

         RideDetailLineChart(
            points: report.points,
            tint: RideDashboardTheme.ice,
            fillsArea: true,
            yDomain: report.yDomain,
            height: 140,
            xCalloutLabel: { "\(Self.compact($0)) \(report.distanceUnit)" },
            yCalloutLabel: { "\(Self.whole($0)) \(report.elevationUnit)" }
         )

         HStack(spacing: 8) {
            RideDetailFootnoteStat(label: "GAIN", value: report.gainText, unit: report.elevationUnit)
            RideDetailFootnoteStat(label: "LOSS", value: report.lossText, unit: report.elevationUnit)
            RideDetailFootnoteStat(label: "HIGH", value: report.maxAltitudeText, unit: report.elevationUnit)
            RideDetailFootnoteStat(label: "LOW", value: report.minAltitudeText, unit: report.elevationUnit)
         }
      }
      .padding(14)
      .rideGlassCard(density: .standard)
   }

   // MARK: - Labels

   private static func compact(_ value: Double) -> String {
      value.formatted(.number.precision(.fractionLength(0...1)))
   }

   private static func whole(_ value: Double) -> String {
      value.formatted(.number.precision(.fractionLength(0)))
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground(scene: .summary)
      RideElevationCard(
         report: RideElevationReport(
            points: (0..<80).map { index in
               RideChartPoint(x: Double(index) / 27, y: 180 + 25 * sin(Double(index) / 9))
            },
            gainText: "+20",
            lossText: "-25",
            maxAltitudeText: "205",
            minAltitudeText: "155",
            elevationUnit: "FT",
            distanceUnit: "MI",
            yDomain: 140...220
         )
      )
      .padding()
   }
   .preferredColorScheme(.dark)
}
