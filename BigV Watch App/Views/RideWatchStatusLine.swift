//
//  RideWatchStatusLine.swift
//  BigV Watch App
//

import SwiftUI

/// GPS health and ride status, one calm line at the top of the glance.
struct RideWatchStatusLine: View {

   let statusText: String
   let hasGPSFix: Bool
   let isConnected: Bool
   var versionText: String = RideWatchVersion.label

   /// Radar is drawn only when the phone mirrors one, so a radar-less rider's
   /// status line is exactly what it was before radar existed.
   var showsRadar: Bool = false
   var isRadarConnected: Bool = false
   var radarTier: RideRadarThreatTier?

   var body: some View {
      HStack(spacing: 5) {
         Circle()
            .fill(hasGPSFix ? RideChromeTokens.ice : Color.white.opacity(0.25))
            .frame(width: 6, height: 6)

         Text(statusText)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)

         Spacer(minLength: 0)

         if showsRadar {
            Image(systemName: .radarIcon)
               .font(.system(size: 9, weight: .semibold))
               .foregroundStyle(radarColor)
               .accessibilityLabel(radarAccessibilityLabel)
         }

         Text(versionText)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.40))
            .accessibilityLabel("Version \(versionText)")

         if !isConnected {
            Image(systemName: .disconnectedIcon)
               .font(.caption2)
               .foregroundStyle(RideChromeTokens.ember)
               .accessibilityLabel("Phone not connected")
         }
      }
      .accessibilityElement(children: .combine)
   }

   // MARK: - Radar Pip

   /// The phone chip's palette exactly: dim when the link is down, ice when
   /// the road is clear, amber and red per tier.
   private var radarColor: Color {
      guard isRadarConnected else { return .white.opacity(0.30) }

      return switch radarTier {
         case .high: RideChromeTokens.halt
         case .approaching: RideChromeTokens.amber
         case nil: RideChromeTokens.ice
      }
   }

   private var radarAccessibilityLabel: String {
      guard isRadarConnected else { return "Radar disconnected" }

      return switch radarTier {
         case .high: "Radar, vehicle approaching fast"
         case .approaching: "Radar, vehicle approaching"
         case nil: "Radar clear"
      }
   }
}

private extension String {
   static let disconnectedIcon = "iphone.slash"
   static let radarIcon = "car.rear.waves.up"
}

#Preview {
   VStack(spacing: 10) {
      RideWatchStatusLine(statusText: "Recording", hasGPSFix: true, isConnected: false)
      RideWatchStatusLine(
         statusText: "Recording",
         hasGPSFix: true,
         isConnected: true,
         showsRadar: true,
         isRadarConnected: true,
         radarTier: .high
      )
   }
   .padding()
   .background(RideChromeTokens.void)
}
