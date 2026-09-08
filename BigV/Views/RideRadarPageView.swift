//
//  RideRadarPageView.swift
//  BigV
//

import SwiftUI

/// The full radar page: a two-lane corridor behind you — the rider ("YOU") at
/// the top, vehicles entering wide at the bottom and rising into a pinch as
/// they close from behind.
///
/// Same convention as the tape — amber approaching, red closing fast with a
/// redundant shape cue, grey when empty — at a size the rider can read at a
/// glance with the phone on the bars.
struct RideRadarPageView: View {

   @Bindable var rideViewModel: RideViewModel
   let onShowRadar: () -> Void

   var body: some View {
      VStack(spacing: 10) {
         header

         RideRadarRoadView(
            tracks: rideViewModel.radarTracks,
            isDimmed: rideViewModel.isRadarDimmed,
            isConnected: rideViewModel.isRadarConnected,
            unitSystem: rideViewModel.unitSystem
         )
         .frame(maxHeight: .infinity)

         RideRadarDataStrip(rideViewModel: rideViewModel)
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 6)
      .accessibilityIdentifier("ride.page.radar")
   }

   // MARK: - Header

   private var header: some View {
      HStack(spacing: 8) {
         Image(systemName: "car.rear.waves.up")
            .font(.caption.weight(.semibold))
            .foregroundStyle(rideViewModel.isRadarConnected ? RideDashboardTheme.ice : RideDashboardTheme.ink(0.4))

         Text("REAR RADAR")
            .font(.caption2.weight(.bold))
            .kerning(1.2)
            .foregroundStyle(RideDashboardTheme.ink(0.7))

         Spacer()

         Text(connectionLabel)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(rideViewModel.isRadarConnected ? RideDashboardTheme.ice.opacity(0.8) : RideDashboardTheme.amber)

         Button(action: onShowRadar) {
            Image(systemName: "gearshape.fill")
               .font(.caption.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ink(0.7))
               .frame(width: 36, height: 36)
               .contentShape(.circle)
         }
         .buttonStyle(.plain)
         .rideGlassChrome(in: Circle())
         .accessibilityLabel("Radar settings")
      }
      .padding(.horizontal, 4)
   }

   private var connectionLabel: String {
      switch rideViewModel.radarConnection {
         case .connected: "LIVE"
         case .scanning: "SEARCHING"
         case .connecting: "CONNECTING"
         case .disconnected: "DISCONNECTED"
      }
   }
}

// MARK: - Data Strip

/// The numbers under the road: the ride on the top row, the radar underneath.
///
/// Speed and distance ride here because a rider in traffic lives on this page
/// and still wants the two figures the dashboard is built around, without
/// swiping back for them. They lead, and larger, for the same reason the hero
/// leads the dashboard.
private struct RideRadarDataStrip: View {

   let rideViewModel: RideViewModel

   var body: some View {
      VStack(spacing: 0) {
         HStack(spacing: 0) {
            metric(
               "SPEED",
               value: rideViewModel.speed,
               unit: rideViewModel.speedUnit,
               size: 28,
               identifier: "ride.radar.speed"
            )
            divider
            metric(
               "DISTANCE",
               value: rideViewModel.distance,
               unit: rideViewModel.distanceUnit,
               size: 28,
               identifier: "ride.radar.distance"
            )
         }
         .padding(.vertical, 10)

         Rectangle()
            .fill(RideDashboardTheme.ink(0.10))
            .frame(height: 1)
            .padding(.horizontal, 14)

         HStack(spacing: 0) {
            metric("VEHICLES", value: "\(rideViewModel.radarVehicleCount)")
            divider
            metric("NEAREST", value: rideViewModel.radarNearestDistance ?? RideFormatters.placeholder)
            divider
            metric(
               "CLOSING",
               value: rideViewModel.radarClosingSpeed ?? RideFormatters.placeholder,
               unit: rideViewModel.radarClosingSpeed != nil ? rideViewModel.speedUnit : nil
            )
            divider
            metric("BATTERY", value: rideViewModel.radarBattery ?? RideFormatters.placeholder)
         }
         .padding(.vertical, 10)
      }
      .frame(maxWidth: .infinity)
      .rideGlassCard(density: .hud)
      .accessibilityElement(children: .combine)
   }

   private func metric(
      _ label: String,
      value: String,
      unit: String? = nil,
      size: CGFloat = 24,
      identifier: String? = nil
   ) -> some View {
      VStack(spacing: 3) {
         HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
               .font(.system(size: size, weight: .bold, design: .rounded))
               .monospacedDigit()
               .kerning(1.1)
               .foregroundStyle(RideDashboardTheme.ink)
               .lineLimit(1)
               .minimumScaleFactor(0.7)
               .accessibilityIdentifier(identifier ?? label)

            if let unit {
               Text(unit)
                  .font(.system(size: 10, weight: .semibold))
                  .foregroundStyle(RideDashboardTheme.ink(0.4))
            }
         }

         Text(label)
            .font(.system(size: 9, weight: .bold))
            .kerning(0.8)
            .foregroundStyle(RideDashboardTheme.ink(0.45))
      }
      .frame(maxWidth: .infinity)
   }

   private var divider: some View {
      Rectangle()
         .fill(RideDashboardTheme.ink(0.10))
         .frame(width: 1, height: 34)
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      RideRadarPageView(rideViewModel: RideViewModel(), onShowRadar: {})
   }
   .preferredColorScheme(.dark)
}
