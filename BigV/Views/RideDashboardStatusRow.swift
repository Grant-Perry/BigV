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
   let onShowRadar: () -> Void
   let onShowSetup: () -> Void

   var body: some View {
      HStack(spacing: 8) {
         RideStatusBar(
            statusText: rideViewModel.statusText,
            showsLabel: !rideViewModel.isRecording,
            accuracyText: rideViewModel.accuracyText,
            issueMessage: rideViewModel.issueMessage,
            hasGPSFix: rideViewModel.hasGPSFix
         )

         if !rideViewModel.isIdle {
            RideHeartRateChip(
               value: rideViewModel.heartRate ?? RideFormatters.placeholder,
               unit: rideViewModel.heartRateUnit,
               beatsPerMinute: rideViewModel.heartRateBeatsPerMinute
            )
         }

         // Live cue whenever a radar is set up; on idle it doubles as the way
         // in to pairing, so the feature is discoverable before first pairing.
         if rideViewModel.isRadarAvailable || rideViewModel.isIdle {
            RideRadarChip(
               connection: rideViewModel.radarConnection,
               tier: rideViewModel.radarTier,
               nearestDistance: rideViewModel.radarNearestDistance,
               battery: rideViewModel.radarBattery,
               action: onShowRadar
            )
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

            Button(action: onShowSetup) {
               Image(systemName: .setupIcon)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.white.opacity(0.75))
                  .frame(width: 36, height: 36)
                  .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .rideGlassChrome(in: Circle())
            .accessibilityLabel("Ride setup")
            .accessibilityIdentifier("ride.button.setup")
         }
      }
   }
}

private extension String {
   static let historyIcon = "clock.arrow.circlepath"
   static let setupIcon = "gearshape.fill"
}
