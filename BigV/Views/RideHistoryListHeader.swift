//
//  RideHistoryListHeader.swift
//  BigV
//

import SwiftUI

/// The line above the list: how many rides, and the whole logbook's distance
/// and time — so the list opens with a career, not a count.
struct RideHistoryListHeader: View {

   let summary: RideHistoryViewModel.Summary

   var body: some View {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
         Text("\(summary.ridesText) RIDES")
            .font(.caption2.weight(.bold))
            .kerning(1.4)
            .foregroundStyle(RideDashboardTheme.ink(0.42))

         Spacer(minLength: 8)

         HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(summary.distanceText)
               .foregroundStyle(RideDashboardTheme.ice)
            Text(summary.distanceUnit)
               .font(.caption2.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ink(0.4))
            Text("·")
               .foregroundStyle(RideDashboardTheme.ink(0.3))
               .padding(.horizontal, 2)
            Text(summary.timeText)
               .foregroundStyle(RideDashboardTheme.ink(0.75))
         }
         .font(.caption.weight(.semibold))
         .monospacedDigit()
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(
         "\(summary.ridesText) rides, \(summary.distanceText) \(summary.distanceUnit) all time, \(summary.timeText) riding"
      )
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground(scene: .rides)
      RideHistoryListHeader(
         summary: RideHistoryViewModel.Summary(
            ridesText: "18",
            distanceText: "94.33",
            distanceUnit: "MI",
            timeText: "16:32:45"
         )
      )
      .padding()
   }
   .preferredColorScheme(.dark)
}
