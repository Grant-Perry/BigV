//
//  RideLapsCard.swift
//  BigV
//

import SwiftUI

/// The ride cut into pieces: manual and auto laps first, then every climb the
/// ride recorded, each with the numbers that made it one.
struct RideLapsCard: View {

   let report: RideLapsReport

   var body: some View {
      VStack(alignment: .leading, spacing: 12) {
         RideDetailCardHeader(
            icon: "flag.fill",
            tint: RideDashboardTheme.ember,
            title: "LAPS & CLIMBS",
            detail: report.summaryText
         )

         VStack(spacing: 8) {
            ForEach(report.lapRows) { row in
               lapRow(row, badgeTint: RideDashboardTheme.ice)
            }

            if !report.lapRows.isEmpty, !report.climbRows.isEmpty {
               Rectangle()
                  .fill(.white.opacity(0.08))
                  .frame(height: 1)
            }

            ForEach(report.climbRows) { row in
               lapRow(row, badgeTint: RideDashboardTheme.ember)
            }
         }
      }
      .padding(14)
      .rideGlassCard(density: .standard)
   }

   // MARK: - Row

   private func lapRow(_ row: RideLapsReport.Row, badgeTint: Color) -> some View {
      HStack(spacing: 10) {
         Text(row.badge)
            .font(.system(size: 10, weight: .bold))
            .kerning(0.6)
            .foregroundStyle(badgeTint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(badgeTint.opacity(0.14), in: .capsule)
            .frame(width: 64, alignment: .leading)

         Text(row.timeText)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)

         Text(row.distanceText)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.6))

         Spacer()

         Text(row.detailText)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.5))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
      }
      .accessibilityElement(children: .combine)
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground(scene: .summary)
      RideLapsCard(
         report: RideLapsReport(
            lapRows: [
               RideLapsReport.Row(id: 1, badge: "LAP 1", timeText: "22:41", distanceText: "5.0 MI", detailText: "13.2 MPH · +320 FT"),
               RideLapsReport.Row(id: 2, badge: "LAP 2", timeText: "24:05", distanceText: "5.0 MI", detailText: "12.5 MPH · +410 FT")
            ],
            climbRows: [
               RideLapsReport.Row(id: 1, badge: "CAT 3", timeText: "11:32", distanceText: "1.8 MI", detailText: "+540 FT @ 5.4% · 850 VAM")
            ],
            summaryText: "2 LAPS · 1 CLIMB"
         )
      )
      .padding()
   }
   .preferredColorScheme(.dark)
}
