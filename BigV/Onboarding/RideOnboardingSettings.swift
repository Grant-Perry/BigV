//
//  RideOnboardingSettings.swift
//  BigV
//

import Foundation

/// Persists whether the marketing onboarding pager has been completed.
@Observable
@MainActor
final class RideOnboardingSettings {

   private enum Key {
      static let completed = "ride.onboarding.completed"
   }

   @ObservationIgnored private let defaults: UserDefaults

   var hasCompletedOnboarding: Bool {
      didSet { defaults.set(hasCompletedOnboarding, forKey: Key.completed) }
   }

   init(defaults: UserDefaults = .standard) {
      self.defaults = defaults
      hasCompletedOnboarding = defaults.bool(forKey: Key.completed)
   }

   /// Clears the completed flag so `RideLaunchGate` shows the pager again.
   func resetOnboarding() {
      hasCompletedOnboarding = false
   }
}
