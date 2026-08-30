//
//  RideHistorySummaryStrip.swift
//  BigV
//

import SwiftUI

/// The whole logbook in one glance at the top of the Rides page: how many
/// rides, how far, how long — so the page opens with a career, not a list.
struct RideHistorySummaryStrip: View {

   let summary: RideHistoryViewModel.Summary

   var body: some View {
      HStack(spacing: 8) {
         RideDetailFootnoteStat(label: "RIDES", value: summary.ridesText)
         RideDetailFootnoteStat(
            label: "TOTAL DISTANCE",
            value: summary.distanceText,
            unit: summary.distanceUnit,
            tint: RideDashboardTheme.ice
         )
         RideDetailFootnoteStat(label: "TOTAL TIME", value: summary.timeText)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .rideGlassCard(density: .hud)
      .accessibilityElement(children: .combine)
      .accessibilityLabel("All time totals")
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground(scene: .rides)
      RideHistorySummaryStrip(
         summary: RideHistoryViewModel.Summary(
            ridesText: "12",
            distanceText: "148.62",
            distanceUnit: "MI",
            timeText: "11:42:08"
         )
      )
      .padding()
   }
   .preferredColorScheme(.dark)
}
