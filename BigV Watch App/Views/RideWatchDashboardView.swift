//
//  RideWatchDashboardView.swift
//  BigV Watch App
//

import SwiftUI

/// The whole Watch app: a glance at the phone's ride, and the remote for it.
struct RideWatchDashboardView: View {

   let rideWatchViewModel: RideWatchViewModel

   @Environment(\.scenePhase) private var scenePhase

   var body: some View {
      ZStack {
         RideWatchAtmosphereBackground()

         ScrollView {
            VStack(spacing: 6) {
               RideWatchStatusLine(
                  statusText: rideWatchViewModel.statusText,
                  hasGPSFix: rideWatchViewModel.hasGPSFix,
                  isConnected: rideWatchViewModel.linkState == .connected
               )

               glance

               RideWatchControlStack(
                  controls: rideWatchViewModel.controls,
                  onSend: rideWatchViewModel.send
               )

               if let noticeText = rideWatchViewModel.noticeText {
                  Text(noticeText)
                     .font(.system(size: 10, weight: .medium))
                     .foregroundStyle(RideChromeTokens.ember)
                     .multilineTextAlignment(.center)
                     .frame(maxWidth: .infinity)
               }
            }
            .padding(.horizontal, 4)
         }
         .scrollBounceBehavior(.basedOnSize)
      }
      .task { await rideWatchViewModel.activate() }
      .onAppear { rideWatchViewModel.noteScene(isActive: scenePhase == .active) }
      .onChange(of: scenePhase) { _, phase in
         rideWatchViewModel.noteScene(isActive: phase == .active)
      }
   }

   // MARK: - Glance

   private var glance: some View {
      VStack(spacing: 6) {
         RideWatchSpeedHero(
            value: rideWatchViewModel.speed,
            unit: rideWatchViewModel.speedUnit,
            isLive: rideWatchViewModel.hasLiveMetrics
         )

         HStack(spacing: 8) {
            RideWatchMetricCell(
               title: "DIST",
               value: rideWatchViewModel.distance,
               unit: rideWatchViewModel.distanceUnit,
               isDimmed: !rideWatchViewModel.hasLiveMetrics
            )

            RideWatchMetricCell(
               title: "TIME",
               value: rideWatchViewModel.elapsedTime,
               isDimmed: !rideWatchViewModel.hasLiveMetrics
            )
         }

         RideWatchMetricCell(
            title: "HEART",
            value: rideWatchViewModel.heartRate,
            unit: rideWatchViewModel.heartRateUnit,
            tint: RideChromeTokens.pulse,
            isDimmed: !rideWatchViewModel.isSensingHeartRate,
            showsHeart: true,
            beatsPerMinute: rideWatchViewModel.heartRateBeatsPerMinute
         )
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .rideWatchCard()
   }
}

#Preview {
   RideWatchDashboardView(rideWatchViewModel: RideWatchViewModel())
}
