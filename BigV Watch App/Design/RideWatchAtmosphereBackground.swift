//
//  RideWatchAtmosphereBackground.swift
//  BigV Watch App
//

import SwiftUI

/// Faded cockpit trail behind the glance. Dropped on always-on so the Watch
/// is not compositing a photo onto a dimmed display for nobody.
struct RideWatchAtmosphereBackground: View {

   @Environment(\.isLuminanceReduced) private var isLuminanceReduced

   var body: some View {
      ZStack {
         RideChromeTokens.void

         if !isLuminanceReduced {
            Image("RideWatchTrailSun")
               .resizable()
               .scaledToFill()
               .opacity(0.42)
               .overlay {
                  LinearGradient(
                     colors: [
                        RideChromeTokens.void.opacity(0.72),
                        RideChromeTokens.void.opacity(0.28),
                        RideChromeTokens.void.opacity(0.78)
                     ],
                     startPoint: .top,
                     endPoint: .bottom
                  )
               }
               .overlay {
                  RadialGradient(
                     colors: [
                        RideChromeTokens.ember.opacity(0.16),
                        .clear
                     ],
                     center: .init(x: 0.50, y: 0.42),
                     startRadius: 4,
                     endRadius: 90
                  )
               }
         }
      }
      .ignoresSafeArea()
      .allowsHitTesting(false)
      .accessibilityHidden(true)
   }
}

#Preview {
   RideWatchAtmosphereBackground()
}
