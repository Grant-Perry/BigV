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

   @Environment(RideBackToStartModel.self) private var backToStartModel

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

         // The way home, once there is a recorded start to go back to. A chip
         // rather than a control-bar button: it is chosen once a ride, calmly.
         if !rideViewModel.isIdle, backToStartModel.isAvailable {
            backToStartChip
         }
      }
      // The speed hero's floor will eat this row if it can. Pin the chips at
      // their intrinsic height so weather, pulse, and radar never collapse
      // into the GPS mark under the cluster.
      .fixedSize(horizontal: false, vertical: true)
      .layoutPriority(2)
      .sheet(isPresented: Bindable(backToStartModel).isPresentingOptions) {
         RideBackToStartSheet(backToStartModel: backToStartModel)
      }
   }

   // MARK: - Back to Start

   private var backToStartChip: some View {
      Button {
         backToStartModel.presentOptions()
      } label: {
         Image(systemName: "house.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
            .frame(width: 34, height: 34)
            .contentShape(.circle)
      }
      .buttonStyle(.plain)
      .rideGlassChrome(in: .circle)
      .accessibilityLabel("Back to start")
      .accessibilityIdentifier("ride.chip.backToStart")
   }
}
