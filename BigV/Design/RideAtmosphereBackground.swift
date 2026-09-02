//
//  RideAtmosphereBackground.swift
//  BigV
//

import SwiftUI

/// Which trail plate a surface should sit on. Maps never use this.
enum RideAtmosphereScene: Sendable {
   case dashboard
   case rides
   case summary
   case speedCluster
   case rideTo

   var plateName: String {
      switch self {
         case .dashboard, .summary:
            RideDashboardTheme.plateOlive
         case .rides:
            RideDashboardTheme.plateDawn
         case .speedCluster:
            RideDashboardTheme.plateEmber
         case .rideTo:
            RideDashboardTheme.plateLupineGold
      }
   }
}

/// Trail plate fill with the required dim wash. Photo only — not chrome.
struct RideTrailPlateView: View {

   let plateName: String

   var body: some View {
      Image(plateName)
         .resizable()
         .scaledToFill()
         .overlay(RideDashboardTheme.veil(0.2))
   }
}

/// Cockpit scene art. Trail plate plus dim vignette so HUD text stays king.
///
/// By day the same plate is washed nearly out: the ground is paper, and a
/// photo that reads as atmosphere at night reads as clutter under black ink
/// in the sun.
struct RideAtmosphereBackground: View {

   var scene: RideAtmosphereScene = .dashboard

   @Environment(\.colorScheme) private var colorScheme

   private var isDark: Bool { colorScheme == .dark }

   var body: some View {
      ZStack {
         RideDashboardTheme.void

         RideTrailPlateView(plateName: scene.plateName)
            .opacity(isDark ? 0.40 : 0.16)
            .overlay {
               LinearGradient(
                  colors: [
                     RideDashboardTheme.void.opacity(0.78),
                     RideDashboardTheme.void.opacity(0.42),
                     RideDashboardTheme.void.opacity(0.80)
                  ],
                  startPoint: .top,
                  endPoint: .bottom
               )
            }
            .overlay {
               RadialGradient(
                  colors: [
                     .clear,
                     RideDashboardTheme.void.opacity(0.55)
                  ],
                  center: .center,
                  startRadius: 80,
                  endRadius: 520
               )
            }

         RadialGradient(
            colors: [
               RideDashboardTheme.ember.opacity(isDark ? 0.14 : 0.08),
               RideDashboardTheme.ember.opacity(0)
            ],
            center: .init(x: 0.50, y: 0.42),
            startRadius: 10,
            endRadius: 280
         )

         RadialGradient(
            colors: [
               RideDashboardTheme.ice.opacity(isDark ? 0.08 : 0.05),
               RideDashboardTheme.ice.opacity(0)
            ],
            center: .init(x: 0.78, y: 0.16),
            startRadius: 8,
            endRadius: 240
         )
      }
      .clipped()
      .allowsHitTesting(false)
      .accessibilityHidden(true)
   }
}

#Preview("Night") {
   RideAtmosphereBackground(scene: .dashboard)
      .preferredColorScheme(.dark)
}

#Preview("Day") {
   RideAtmosphereBackground(scene: .dashboard)
      .preferredColorScheme(.light)
}
