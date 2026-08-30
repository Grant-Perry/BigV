//
//  RideLaunchGate.swift
//  BigV
//

import SwiftUI

/// Owns splash → onboarding (first launch) → cockpit.
struct RideLaunchGate<Root: View>: View {

   @Bindable var plusStore: BigVeloPlusStore
   @Bindable var onboardingSettings: RideOnboardingSettings
   @ViewBuilder var root: () -> Root

   @Environment(\.accessibilityReduceMotion) private var reduceMotion
   @State private var phase: Phase = .splash

   private enum Phase: Equatable {
      case splash
      case onboarding
      case root
   }

   var body: some View {
      ZStack {
         switch phase {
            case .splash:
               RideSplashView {
                  advanceFromSplash()
               }
               .transition(splashTransition)

            case .onboarding:
               RideOnboardingView(plusStore: plusStore) {
                  onboardingSettings.hasCompletedOnboarding = true
                  withAnimation(reduceMotion ? .easeOut(duration: 0.25) : .easeInOut(duration: 0.4)) {
                     phase = .root
                  }
               }
               .transition(splashTransition)

            case .root:
               root()
                  .transition(splashTransition)
         }
      }
      .animation(reduceMotion ? .easeOut(duration: 0.25) : .easeInOut(duration: 0.4), value: phase)
      .onChange(of: onboardingSettings.hasCompletedOnboarding) { _, completed in
         // Settings can reopen onboarding by clearing the flag.
         if !completed, phase == .root {
            withAnimation(reduceMotion ? .easeOut(duration: 0.25) : .easeInOut(duration: 0.35)) {
               phase = .onboarding
            }
         }
      }
   }

   // MARK: - Transitions

   private var splashTransition: AnyTransition {
      reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 1.02))
   }

   private func advanceFromSplash() {
      let next: Phase = onboardingSettings.hasCompletedOnboarding ? .root : .onboarding
      withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .easeInOut(duration: 0.45)) {
         phase = next
      }
   }
}
