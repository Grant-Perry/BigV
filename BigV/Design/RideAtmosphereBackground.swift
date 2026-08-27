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
         .overlay(Color.black.opacity(0.2))
   }
}

/// Cockpit scene art. Trail plate plus dim vignette so HUD text stays king.
struct RideAtmosphereBackground: View {

   var scene: RideAtmosphereScene = .dashboard

   var body: some View {
      ZStack {
         RideDashboardTheme.void

         RideTrailPlateView(plateName: scene.plateName)
            .opacity(0.40)
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
               RideDashboardTheme.ember.opacity(0.14),
               RideDashboardTheme.ember.opacity(0)
            ],
            center: .init(x: 0.50, y: 0.42),
            startRadius: 10,
            endRadius: 280
         )

         RadialGradient(
            colors: [
               RideDashboardTheme.ice.opacity(0.08),
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

#Preview {
   RideAtmosphereBackground(scene: .dashboard)
}
