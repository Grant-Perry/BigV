//
//  RideGlassCard.swift
//  BigV
//

import SwiftUI

/// How dark a content-card wash should read.
///
/// HUD is for glanceable metric text on a vibrating bike. Standard is for larger
/// landing and summary panes. Neither is Liquid Glass — dense cards use a
/// gradient wash so they stay readable and never sample other glass.
enum RideGlassDensity: Sendable {
   case standard
   case hud
}

/// Gradient-wash content card with an inner highlight edge.
///
/// At night the wash is smoked graphite with a white specular edge. By day it
/// is near-white paper with a hair of ink around it and a soft drop shadow, so
/// a card still lifts off the ground when there is no darkness to lift from.
struct RideGlassCard<Content: View>: View {

   var density: RideGlassDensity = .hud
   var cornerRadius: CGFloat = RideDashboardTheme.cardRadius
   @ViewBuilder var content: () -> Content

   @Environment(\.colorScheme) private var colorScheme

   var body: some View {
      content()
         .background(wash, in: shape)
         .overlay {
            shape
               .strokeBorder(highlight, lineWidth: 1)
         }
         .shadow(
            color: .black.opacity(colorScheme == .dark ? 0 : 0.07),
            radius: 10,
            y: 4
         )
   }

   // MARK: - Materials

   private var shape: RoundedRectangle {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
   }

   private var wash: LinearGradient {
      switch (density, colorScheme) {
         case (.hud, .dark):
            LinearGradient(
               colors: [
                  Color.white.opacity(0.11),
                  RideDashboardTheme.graphite.opacity(0.88),
                  Color.black.opacity(0.62)
               ],
               startPoint: .topLeading,
               endPoint: .bottomTrailing
            )

         case (.standard, .dark):
            LinearGradient(
               colors: [
                  Color.white.opacity(0.14),
                  RideDashboardTheme.graphite.opacity(0.72),
                  RideDashboardTheme.midnight.opacity(0.55)
               ],
               startPoint: .topLeading,
               endPoint: .bottomTrailing
            )

         case (.hud, _):
            LinearGradient(
               colors: [
                  Color.white.opacity(0.97),
                  Color.white.opacity(0.88),
                  RideDashboardTheme.graphite.opacity(0.92)
               ],
               startPoint: .topLeading,
               endPoint: .bottomTrailing
            )

         case (.standard, _):
            LinearGradient(
               colors: [
                  Color.white.opacity(0.97),
                  Color.white.opacity(0.86),
                  RideDashboardTheme.midnight.opacity(0.60)
               ],
               startPoint: .topLeading,
               endPoint: .bottomTrailing
            )
      }
   }

   private var highlight: LinearGradient {
      if colorScheme == .dark {
         LinearGradient(
            colors: [
               Color.white.opacity(density == .hud ? 0.20 : 0.26),
               Color.white.opacity(0.04),
               RideDashboardTheme.ice.opacity(0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
         )
      } else {
         LinearGradient(
            colors: [
               RideDashboardTheme.ink(0.12),
               RideDashboardTheme.ink(0.05),
               RideDashboardTheme.ice.opacity(0.22)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
         )
      }
   }
}

extension View {

   /// Large content panes: dashboard tiles, summary cards, history rows.
   func rideGlassCard(
      density: RideGlassDensity = .hud,
      cornerRadius: CGFloat = RideDashboardTheme.cardRadius
   ) -> some View {
      RideGlassCard(density: density, cornerRadius: cornerRadius) { self }
   }

   /// Small floating chrome: pills, FABs, destination chips. Native Liquid Glass.
   @ViewBuilder
   func rideGlassChrome<S: Shape>(in shape: S, tint: Color? = nil) -> some View {
      if let tint {
         self.glassEffect(.regular.tint(tint), in: shape)
      } else {
         self.glassEffect(.regular, in: shape)
      }
   }
}
