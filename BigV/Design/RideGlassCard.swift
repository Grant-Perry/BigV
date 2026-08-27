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
struct RideGlassCard<Content: View>: View {

   var density: RideGlassDensity = .hud
   var cornerRadius: CGFloat = RideDashboardTheme.cardRadius
   @ViewBuilder var content: () -> Content

   var body: some View {
      content()
         .background(wash, in: shape)
         .overlay {
            shape
               .strokeBorder(highlight, lineWidth: 1)
         }
   }

   // MARK: - Materials

   private var shape: RoundedRectangle {
      RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
   }

   private var wash: LinearGradient {
      switch density {
         case .hud:
            LinearGradient(
               colors: [
                  Color.white.opacity(0.11),
                  RideDashboardTheme.graphite.opacity(0.88),
                  Color.black.opacity(0.62)
               ],
               startPoint: .topLeading,
               endPoint: .bottomTrailing
            )

         case .standard:
            LinearGradient(
               colors: [
                  Color.white.opacity(0.14),
                  RideDashboardTheme.graphite.opacity(0.72),
                  RideDashboardTheme.midnight.opacity(0.55)
               ],
               startPoint: .topLeading,
               endPoint: .bottomTrailing
            )
      }
   }

   private var highlight: LinearGradient {
      LinearGradient(
         colors: [
            Color.white.opacity(density == .hud ? 0.20 : 0.26),
            Color.white.opacity(0.04),
            RideDashboardTheme.ice.opacity(0.10)
         ],
         startPoint: .topLeading,
         endPoint: .bottomTrailing
      )
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
