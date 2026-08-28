//
//  RideDashboardStatusRow.swift
//  BigV
//

import SwiftUI

/// Status, address search, and history. Search is always on this row.
struct RideDashboardStatusRow: View {

   let rideViewModel: RideViewModel
   let onShowHistory: () -> Void
   let onPlanRoute: () -> Void

   var body: some View {
      HStack(spacing: 8) {
         RideStatusBar(
            statusText: rideViewModel.statusText,
            accuracyText: rideViewModel.accuracyText,
            issueMessage: rideViewModel.issueMessage,
            hasGPSFix: rideViewModel.hasGPSFix
         )

         if let heartRate = rideViewModel.heartRate {
            RideHeartRateChip(value: heartRate, unit: rideViewModel.heartRateUnit)
         }

         RideSearchButton(style: .chip, identifier: "ride.button.search", action: onPlanRoute)

         if rideViewModel.isIdle {
            Button(action: onShowHistory) {
               HStack(spacing: 6) {
                  Image(systemName: .historyIcon)
                     .font(.caption.weight(.semibold))
                  Text("RIDES")
                     .font(.caption2.weight(.bold))
                     .kerning(0.8)
               }
               .foregroundStyle(.white.opacity(0.88))
               .padding(.horizontal, 12)
               .frame(height: 36)
               .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .rideGlassChrome(in: Capsule())
            .accessibilityLabel("Ride history")
            .accessibilityIdentifier("ride.button.history")
         }
      }
   }
}

private extension String {
   static let historyIcon = "clock.arrow.circlepath"
}
