//
//  RideSplashView.swift
//  BigV
//

import SwiftUI
import UIKit

/// Branded SwiftUI splash after the void system launch screen.
///
/// Holds ~1.2–1.8s then yields. Reduce Motion: crossfade only, no scale drift.
struct RideSplashView: View {

   var onFinished: () -> Void

   @Environment(\.accessibilityReduceMotion) private var reduceMotion
   @State private var isVisible = false

   private let holdNanoseconds: UInt64 = 1_500_000_000

   var body: some View {
      ZStack {
         RideDashboardTheme.void

         plate
            .opacity(isVisible ? 1 : (reduceMotion ? 0 : 0.85))
            .scaleEffect(reduceMotion || isVisible ? 1 : 1.04)

         VStack(spacing: 14) {
            Spacer()

            Text("BigVelo")
               .font(.system(size: 42, weight: .bold, design: .rounded))
               .foregroundStyle(.white)
               .shadow(color: .black.opacity(0.55), radius: 12, y: 4)

            Capsule()
               .fill(RideDashboardTheme.ember)
               .frame(width: 48, height: 3)
               .shadow(color: RideDashboardTheme.ember.opacity(0.55), radius: 8, y: 0)

            Text("Phone computer. Watch heart. Eyes behind you.")
               .font(.footnote.weight(.medium))
               .foregroundStyle(.white.opacity(0.72))
               .multilineTextAlignment(.center)
               .padding(.horizontal, 28)

            Spacer()
            Spacer()
         }
         .opacity(isVisible ? 1 : 0)
      }
      .ignoresSafeArea()
      .preferredColorScheme(.dark)
      .task {
         withAnimation(reduceMotion ? .easeOut(duration: 0.35) : .easeOut(duration: 0.55)) {
            isVisible = true
         }
         try? await Task.sleep(for: .nanoseconds(holdNanoseconds))
         onFinished()
      }
   }

   // MARK: - Plate

   @ViewBuilder
   private var plate: some View {
      if UIImage(named: RideOnboardingArt.splash) != nil {
         Image(RideOnboardingArt.splash)
            .resizable()
            .scaledToFill()
            .overlay {
               LinearGradient(
                  colors: [
                     RideDashboardTheme.void.opacity(0.55),
                     RideDashboardTheme.void.opacity(0.25),
                     RideDashboardTheme.void.opacity(0.82)
                  ],
                  startPoint: .top,
                  endPoint: .bottom
               )
            }
      } else {
         RideAtmosphereBackground(scene: .speedCluster)
      }
   }
}

#Preview {
   RideSplashView(onFinished: {})
}
