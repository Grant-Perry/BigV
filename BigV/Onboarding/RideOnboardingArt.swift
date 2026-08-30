//
//  RideOnboardingArt.swift
//  BigV
//

import Foundation

/// Asset catalog names for splash / onboarding plates.
///
/// Higgsfield stills when present; views fall back to trail atmospheres if a
/// name is missing at runtime.
enum RideOnboardingArt {
   static let splash = "OnboardSplash"
   static let kit = "OnboardKit"
   static let radar = "OnboardRadar"
   static let story = "OnboardStory"

   /// Trail-plate fallbacks when a generated still is absent.
   static func fallbackPlate(for page: RideOnboardingPageID) -> String {
      switch page {
         case .kit: RideDashboardTheme.plateOlive
         case .radar: RideDashboardTheme.plateEmber
         case .story: RideDashboardTheme.plateDawn
         case .plus: RideDashboardTheme.plateLupineGold
      }
   }
}

enum RideOnboardingPageID: Int, CaseIterable, Identifiable, Hashable {
   case kit = 0
   case radar = 1
   case story = 2
   case plus = 3

   var id: Int { rawValue }

   var title: String {
      switch self {
         case .kit: "Your kit"
         case .radar: "The road behind"
         case .story: "The story after"
         case .plus: "BigVelo+"
      }
   }

   var body: String {
      switch self {
         case .kit:
            "Your iPhone is the computer. Your Apple Watch is the heart-rate sensor — no strap. Start, pause and end from the wrist."
         case .radar:
            "Works with Garmin Varia™ and compatible Bluetooth cycling radars. Live rear tape, green / amber / red, and a buzz on your wrist when a car is back. BigVelo is not affiliated with Garmin."
         case .story:
            "End a ride and it still lives: map, traffic passes, speed, elevation, heart rate and the weather you rode through."
         case .plus:
            "Try BigVelo+ free for 7 days on yearly. Radar, Watch HR, record, History and Health stay free either way."
      }
   }

   var plateName: String {
      switch self {
         case .kit: RideOnboardingArt.kit
         case .radar: RideOnboardingArt.radar
         case .story: RideOnboardingArt.story
         case .plus: RideOnboardingArt.splash
      }
   }
}
