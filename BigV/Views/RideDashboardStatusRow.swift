//
//  RideDashboardStatusRow.swift
//  BigV
//

import SwiftUI

/// GPS status and the live sensor chips — sky, heart, road behind.
///
/// Navigation left this row when the tab bar arrived. What stays is only what
/// reports on the ride itself, which is why the chips finally have the width to
/// print a full reading instead of an ellipsis.
struct RideDashboardStatusRow: View {

   let rideViewModel: RideViewModel
   let onShowRadar: () -> Void

   var body: some View {
      HStack(spacing: 8) {
         RideStatusBar(
            statusText: rideViewModel.statusText,
            showsLabel: !rideViewModel.isRecording,
            accuracyText: rideViewModel.accuracyText,
            issueMessage: rideViewModel.issueMessage,
            hasGPSFix: rideViewModel.hasGPSFix
         )

         // Always on the row, idle included: the sky is the first thing a
         // rider checks, and it is checked before rolling out, not during.
         RideWeatherChip()

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
      }
   }
}
