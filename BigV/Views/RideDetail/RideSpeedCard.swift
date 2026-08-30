//
//  RideSpeedCard.swift
//  BigV
//

import SwiftUI

/// Speed over distance, with the ride average drawn as a reference line so
/// every surge and every stop reads at a glance.
struct RideSpeedCard: View {

   let report: RideSpeedReport

   var body: some View {
      VStack(alignment: .leading, spacing: 12) {
         RideDetailCardHeader(
            icon: "gauge.with.needle.fill",
            tint: RideDashboardTheme.ember,
            title: "SPEED",
            detail: "\(report.averageText) AVG · \(report.maximumText) MAX"
         )

         RideDetailLineChart(
            points: report.points,
            tint: RideDashboardTheme.ember,
            fillsArea: true,
            averageY: report.averageValue,
            height: 130,
            xCalloutLabel: { "\(Self.compact($0)) \(report.distanceUnit)" },
            yCalloutLabel: { "\(Self.compact($0)) \(report.speedUnit)" }
         )

         HStack(spacing: 8) {
            RideDetailFootnoteStat(
               label: "AVERAGE",
               value: report.averageText,
               unit: report.speedUnit,
               tint: RideDashboardTheme.ember
            )
            RideDetailFootnoteStat(
               label: "MAX",
               value: report.maximumText,
               unit: report.speedUnit
            )
         }
      }
      .padding(14)
      .rideGlassCard(density: .standard)
   }

   // MARK: - Labels

   private static func compact(_ value: Double) -> String {
      value.formatted(.number.precision(.fractionLength(0...1)))
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground(scene: .summary)
      RideSpeedCard(
         report: RideSpeedReport(
            points: (0..<80).map { index in
               RideChartPoint(x: Double(index) / 27, y: max(0, 19 + 7 * sin(Double(index) / 5)))
            },
            averageValue: 19.2,
            averageText: "19.2",
            maximumText: "26.9",
            speedUnit: "MPH",
            distanceUnit: "MI"
         )
      )
      .padding()
   }
   .preferredColorScheme(.dark)
}
