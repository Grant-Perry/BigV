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
}

private extension String {
   static let disconnectedIcon = "iphone.slash"
}

#Preview {
   RideWatchStatusLine(statusText: "Recording", hasGPSFix: true, isConnected: false)
      .padding()
      .background(RideChromeTokens.void)
}
