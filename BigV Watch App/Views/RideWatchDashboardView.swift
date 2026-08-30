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
            VStack(spacing: 8) {
               RideWatchStatusLine(
                  statusText: rideWatchViewModel.statusText,
                  hasGPSFix: rideWatchViewModel.hasGPSFix,
                  isConnected: rideWatchViewModel.linkState == .connected,
                  showsRadar: rideWatchViewModel.hasRadar,
                  isRadarConnected: rideWatchViewModel.isRadarConnected,
                  radarTier: rideWatchViewModel.radarTier
               )

               // Sits with the status line rather than below the card. Trouble
               // the rider needs to read must not be parked in the one strip
               // the pinned remote covers.
               if let noticeText = rideWatchViewModel.noticeText {
                  Text(noticeText)
                     .font(.system(size: 10, weight: .medium))
                     .foregroundStyle(RideChromeTokens.ember)
                     .multilineTextAlignment(.leading)
                     .frame(maxWidth: .infinity, alignment: .leading)
               }

               glance
            }
            .padding(.horizontal, 6)
         }
         .scrollBounceBehavior(.basedOnSize)
         // The remote is pinned, never scrolled. A rider reaching for PAUSE
         // mid-descent cannot be asked to go looking for it first, and an
         // inset — rather than a bottom pad — is what keeps the glance clear
         // of it however tall the card grows.
         .safeAreaInset(edge: .bottom) {
            RideWatchControlStack(
               controls: rideWatchViewModel.controls,
               onSend: rideWatchViewModel.send
            )
            .padding(.top, 10)
            .background {
               // A glance taller than the screen scrolls under the remote. The
               // fade makes that read as depth instead of a collision.
               LinearGradient(
                  colors: [
                     RideChromeTokens.void.opacity(0),
                     RideChromeTokens.void.opacity(0.88)
                  ],
                  startPoint: .top,
                  endPoint: .bottom
               )
               .ignoresSafeArea()
            }
         }
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

         if rideWatchViewModel.hasRadar {
            RideWatchRadarStrip(
               isConnected: rideWatchViewModel.isRadarConnected,
               tier: rideWatchViewModel.radarTier,
               vehicleCount: rideWatchViewModel.radarVehicleCount,
               nearestDistanceMeters: rideWatchViewModel.radarNearestMeters,
               nearestDistanceText: rideWatchViewModel.radarNearestDistance
            )
         }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .rideWatchCard()
   }
}

#Preview {
   RideWatchDashboardView(rideWatchViewModel: RideWatchViewModel())
}
