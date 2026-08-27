//
//  RideStatusBar.swift
//  BigV
//

import SwiftUI

/// GPS health and ride status, kept deliberately small and calm.
struct RideStatusBar: View {

   let statusText: String
   let accuracyText: String?
   let issueMessage: String?
   let hasGPSFix: Bool

   var body: some View {
      VStack(spacing: 6) {
         HStack(spacing: 8) {
            RideMarkView(isLive: hasGPSFix)

            Text(statusText)
               .font(.caption.weight(.semibold))
               .foregroundStyle(.white.opacity(0.88))

            Spacer()

            if let accuracyText {
               Text(accuracyText)
                  .font(.caption2.weight(.medium))
                  .monospacedDigit()
                  .foregroundStyle(.white.opacity(0.5))
            }
         }

         if let issueMessage {
            Text(issueMessage)
               .font(.caption2)
               .foregroundStyle(RideDashboardTheme.ember)
               .frame(maxWidth: .infinity, alignment: .leading)
         }
      }
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      RideStatusBar(
         statusText: "Recording",
         accuracyText: "8 m",
         issueMessage: nil,
         hasGPSFix: true
      )
      .padding()
   }
}
