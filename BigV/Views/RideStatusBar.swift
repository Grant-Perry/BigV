//
//  RideStatusBar.swift
//  BigV
//

import SwiftUI

/// GPS health and ride status, kept deliberately small and calm.
struct RideStatusBar: View {

   /// The full phase wording. VoiceOver always reads it, even when the row is
   /// drawn wordless.
   let statusText: String

   /// Whether the wording is drawn. The portrait row shares its width with the
   /// sensor chips, and once it is tight the one status worth no letters is the
   /// obvious one — a live mark, ticking clock, and rolling speed already say
   /// "recording" louder than a caption ever could.
   var showsLabel = true

   let accuracyText: String?
   let issueMessage: String?
   let hasGPSFix: Bool

   var body: some View {
      VStack(spacing: 6) {
         HStack(spacing: 8) {
            RideMarkView(isLive: hasGPSFix)

            if showsLabel {
               Text(statusText)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(RideDashboardTheme.ink(0.88))
            }

            Spacer(minLength: 0)

            if let accuracyText {
               Text(accuracyText)
                  .font(.caption2.weight(.medium))
                  .monospacedDigit()
                  .foregroundStyle(RideDashboardTheme.ink(0.5))
            }
         }
         // Never wrap: a two-line status shoves the whole cockpit down.
         .lineLimit(1)
         .minimumScaleFactor(0.85)
         .accessibilityElement(children: .ignore)
         .accessibilityLabel(statusText)
         .accessibilityValue(accuracyText.map { "GPS accuracy \($0)" } ?? "")

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
      VStack(spacing: 16) {
         RideStatusBar(
            statusText: "Recording",
            showsLabel: false,
            accuracyText: "8 m",
            issueMessage: nil,
            hasGPSFix: true
         )

         RideStatusBar(
            statusText: "Acquiring GPS",
            accuracyText: nil,
            issueMessage: "Waiting for a fix",
            hasGPSFix: false
         )
      }
      .padding()
   }
}
