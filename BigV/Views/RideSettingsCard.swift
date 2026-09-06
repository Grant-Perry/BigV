//
//  RideSettingsCard.swift
//  BigV
//

import SwiftUI

/// Shape metrics shared by a settings card and the rows living inside it.
enum RideSettingsMetrics {

   /// A card's inner inset. `RideSettingsDivider` negates it to reach the edges.
   static let cardPadding: CGFloat = 14

   static let rowCornerRadius: CGFloat = 12
}

/// A settings group: kerned header, stacked rows, one quiet footnote.
///
/// Settings groups related switches rather than giving every preference its own
/// pane, so the scaffold is a type instead of a private helper — a card with a
/// header, hairline-separated rows and a single closing note reads the same in
/// every section, and a new section cannot drift.
struct RideSettingsCard<Content: View>: View {

   var title: String?

   /// One line, and live where it can be: a note that names the rider's current
   /// choice teaches more than a paragraph describing every choice.
   var footnote: String?

   @ViewBuilder var content: () -> Content

   var body: some View {
      VStack(alignment: .leading, spacing: 10) {
         if let title {
            Text(title)
               .font(.caption2.weight(.bold))
               .kerning(1.2)
               .foregroundStyle(RideDashboardTheme.ink(0.45))
         }

         content()

         if let footnote {
            Text(footnote)
               .font(.caption2)
               .foregroundStyle(RideDashboardTheme.ink(0.42))
               .fixedSize(horizontal: false, vertical: true)
         }
      }
      .padding(RideSettingsMetrics.cardPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .rideGlassCard()
   }
}

// MARK: - Divider

/// The hairline between rows of one card, run out to the card's edges.
///
/// An inset rule reads as decoration inside a paragraph. An edge-to-edge one
/// reads as a boundary between rows, which is the only reason it is there.
struct RideSettingsDivider: View {

   var body: some View {
      Rectangle()
         .fill(RideDashboardTheme.ink(0.09))
         .frame(height: 1)
         .frame(maxWidth: .infinity)
         .padding(.horizontal, -RideSettingsMetrics.cardPadding)
         .accessibilityHidden(true)
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()

      RideSettingsCard(
         title: "UNITS",
         footnote: "mph · miles · feet · 72°F — speed, distance, elevation, radar ranges, history and your Watch."
      ) {
         Text("Measurement")
            .foregroundStyle(RideDashboardTheme.ink)

         RideSettingsDivider()

         Text("Temperature")
            .foregroundStyle(RideDashboardTheme.ink)
      }
      .padding(16)
   }
   .preferredColorScheme(.dark)
}
