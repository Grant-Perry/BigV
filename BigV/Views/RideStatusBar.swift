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
            Image(systemName: hasGPSFix ? .locationFillIcon : .locationSlashIcon)
               .font(.caption.weight(.bold))
               .foregroundStyle(hasGPSFix ? .green : .orange)

            Text(statusText)
               .font(.caption.weight(.semibold))
               .foregroundStyle(.white.opacity(0.8))

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
               .foregroundStyle(.orange)
               .frame(maxWidth: .infinity, alignment: .leading)
         }
      }
   }
}

// MARK: - Icons

private extension String {
   static let locationFillIcon = "location.fill"
   static let locationSlashIcon = "location.slash"
}

#Preview {
   ZStack {
      Color.black
      RideStatusBar(
         statusText: "Recording",
         accuracyText: "8 m",
         issueMessage: nil,
         hasGPSFix: true
      )
      .padding()
   }
}
