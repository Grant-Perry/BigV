//
//  RideDashboardStatusRow.swift
//  BigV
//

import SwiftUI

/// GPS status and the live sensor chips — sky, heart, road behind.
///
/// Navigation left this row when the tab bar arrived. What stays is only what
/// reports on the ride itself.
///
/// The chips are fixed-size and the status bar is the one flexible member, so
/// when the row runs short it is the phase word and the accuracy figure that
/// give ground. A readable sensor beats a readable caption: "Recording" is
/// already obvious from the rolling numbers, whereas a heart rate abbreviated
/// to "8 B" is actively misleading.
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
         .layoutPriority(-1)

         // Always on the row, idle included: the sky is the first thing a
         // rider checks, and it is checked before rolling out, not during.
         RideWeatherChip()

         if !rideViewModel.isIdle {
            RideHeartRateChip(
               value: rideViewModel.heartRate ?? RideFormatters.placeholder,
               unit: rideViewModel.heartRateUnit,
               beatsPerMinute: rideViewModel.heartRateBeatsPerMinute,
               isSelected: rideViewModel.selectedMetric == .heartRate,
               action: { rideViewModel.selectMetric(.heartRate) }
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
               isSelected: rideViewModel.isLiveRadarTimelineVisible,
               action: {
                  if rideViewModel.isIdle {
                     onShowRadar()
                  } else {
                     rideViewModel.toggleLiveRadarTimeline()
                  }
               }
            )
         }
      }
   }
}
