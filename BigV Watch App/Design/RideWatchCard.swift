//
//  RideWatchCard.swift
//  BigV Watch App
//

import SwiftUI

/// The wrist-sized version of the phone's content card.
///
/// Gradient wash with a highlight edge, exactly like `RideGlassCard` — dense
/// metric text has to stay readable on a vibrating bike, and a material that
/// samples what is behind it does not. Deliberately not Liquid Glass, and
/// deliberately without the phone's trail-plate art: that atmosphere is wrong at
/// this size and costs battery to composite on an always-on display.
struct RideWatchCard<Content: View>: View {

   var cornerRadius: CGFloat = 12
   @ViewBuilder var content: () -> Content

   var body: some View {
      content()
         .background(wash, in: shape)
         .overlay {
            shape.strokeBorder(highlight, lineWidth: 1)
         }
   }

   // MARK: - Materials

   private var shape: RoundedRectangle {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
   }

   private var wash: LinearGradient {
      LinearGradient(
         colors: [
            Color.white.opacity(0.10),
            RideChromeTokens.graphite.opacity(0.90),
            Color.black.opacity(0.66)
         ],
         startPoint: .topLeading,
         endPoint: .bottomTrailing
      )
   }

   private var highlight: LinearGradient {
      LinearGradient(
         colors: [
            Color.white.opacity(0.18),
            Color.white.opacity(0.04),
            RideChromeTokens.ice.opacity(0.10)
         ],
         startPoint: .topLeading,
         endPoint: .bottomTrailing
      )
   }
}

extension View {

   func rideWatchCard(cornerRadius: CGFloat = 12) -> some View {
      RideWatchCard(cornerRadius: cornerRadius) { self }
   }
}
