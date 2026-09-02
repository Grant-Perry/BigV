//
//  RideHistoryRideCard.swift
//  BigV
//

import SwiftUI

/// One older ride on the landing page.
struct RideHistoryRideCard: View {

   let row: RideHistoryViewModel.Row
   let distanceUnit: String

   var body: some View {
      HStack(alignment: .center, spacing: 14) {
         VStack(alignment: .leading, spacing: 4) {
            Text(row.dateText)
               .font(.subheadline.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ink)

            Text("\(row.averageSpeedText) \(row.speedUnit) avg")
               .font(.caption.weight(.medium))
               .monospacedDigit()
               .foregroundStyle(RideDashboardTheme.ink(0.42))
         }

         Spacer(minLength: 8)

         VStack(alignment: .trailing, spacing: 2) {
            Text("\(row.distanceText) \(distanceUnit)")
               .font(.body.weight(.semibold))
               .monospacedDigit()
               .foregroundStyle(RideDashboardTheme.ink)

            Text(row.durationText)
               .font(.caption.weight(.medium))
               .monospacedDigit()
               .foregroundStyle(RideDashboardTheme.ink(0.45))
         }

         Image(systemName: .chevronIcon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(RideDashboardTheme.ink(0.28))
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .rideGlassCard(density: .hud)
      .accessibilityElement(children: .combine)
      .accessibilityLabel(row.dateText)
      .accessibilityValue("\(row.distanceText) \(distanceUnit), \(row.durationText)")
   }
}

private extension String {
   static let chevronIcon = "chevron.right"
}
