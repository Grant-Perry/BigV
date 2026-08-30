//
//  RideHeartRateCard.swift
//  BigV
//

import SwiftUI

/// The pulse story: heart rate over the ride with its high and low flagged on
/// the line, plus calories when Apple Health measured them.
///
/// Renders stats-only when a ride has calories but no pulse series, so the
/// health card never shows an empty chart.
struct RideHeartRateCard: View {

   let report: RideHeartRateReport

   var body: some View {
      VStack(alignment: .leading, spacing: 12) {
         RideDetailCardHeader(
            icon: "heart.fill",
            tint: RideDashboardTheme.pulse,
            title: "HEART RATE",
            detail: hasSeries ? "\(report.averageText) AVG BPM" : nil
         )

         if hasSeries {
            RideDetailLineChart(
               points: report.points,
               tint: RideDashboardTheme.pulse,
               peakPoint: report.maximumPoint,
               lowPoint: report.minimumPoint,
               height: 140,
               xCalloutLabel: { Self.elapsed($0) },
               yCalloutLabel: { "\(Self.whole($0)) BPM" }
            )
         }

         statRow

         if report.isFromAppleHealth {
            Text("From Apple Health")
               .font(.system(size: 9, weight: .medium))
               .foregroundStyle(.white.opacity(0.35))
         }
      }
      .padding(14)
      .rideGlassCard(density: .standard)
   }

   // MARK: - Stats

   private var statRow: some View {
      HStack(spacing: 8) {
         if hasSeries {
            RideDetailFootnoteStat(
               label: "AVG",
               value: report.averageText,
               unit: "BPM",
               tint: RideDashboardTheme.pulse
            )
            RideDetailFootnoteStat(label: "MAX", value: report.maximumText, unit: "BPM")
            RideDetailFootnoteStat(label: "MIN", value: report.minimumText, unit: "BPM")
         }

         if let calories = report.caloriesText {
            RideDetailFootnoteStat(
               label: "ACTIVE",
               value: calories,
               unit: "CAL",
               tint: RideDashboardTheme.ember
            )
         }
      }
   }

   private var hasSeries: Bool { !report.points.isEmpty }

   // MARK: - Labels

   private static func whole(_ value: Double) -> String {
      value.formatted(.number.precision(.fractionLength(0)))
   }

   /// Minutes into the ride, worded the way a rider thinks: "at 23 min".
   private static func elapsed(_ minutes: Double) -> String {
      "at \(minutes.formatted(.number.precision(.fractionLength(0)))) min"
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground(scene: .summary)
      RideHeartRateCard(
         report: RideHeartRateReport(
            points: (0..<80).map { index in
               RideChartPoint(x: Double(index) / 7, y: 132 + 25 * sin(Double(index) / 8))
            },
            averageText: "138",
            maximumText: "165",
            minimumText: "104",
            maximumPoint: RideChartPoint(x: 5.4, y: 165),
            minimumPoint: RideChartPoint(x: 0.6, y: 104),
            caloriesText: "212",
            isFromAppleHealth: true
         )
      )
      .padding()
   }
   .preferredColorScheme(.dark)
}
