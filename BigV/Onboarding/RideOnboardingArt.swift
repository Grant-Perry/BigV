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
         case .ahead: RideDashboardTheme.plateDawn
         case .story: RideDashboardTheme.plateDawn
         case .plus: RideDashboardTheme.plateLupineGold
      }
   }
}

struct RideOnboardingHighlight: Hashable {
   let symbol: String
   let text: String
}

enum RideOnboardingPageID: Int, CaseIterable, Identifiable, Hashable {
   case kit = 0
   case radar = 1
   case ahead = 2
   case story = 3
   case plus = 4

   var id: Int { rawValue }

   var title: String {
      switch self {
         case .kit: "Your kit"
         case .radar: "Behind you…"
         case .ahead: "Ahead of you"
         case .story: "After you stop"
         case .plus: "Keep BigVelo"
      }
   }

   /// First line under the title. Radar keeps the compatibility claim on its own line.
   var lead: String? {
      switch self {
         case .radar: "BigVelo is Garmin Varia™ rear radar compatible."
         default: nil
      }
   }

   var body: String {
      switch self {
         case .kit:
            "Your iPhone is the computer. Your Apple Watch is the heart-rate sensor — no strap. Start, pause and end from the wrist."
         case .radar:
            "Cars coming up behind you show on a live strip we call the tape — green when they’re far, amber as they close, red when they’re close; it even shows their speed! Your Watch buzzes. And the tape follows you between screens."
         case .ahead:
            "The road isn’t only behind you. Turn-by-turn on the phone, voice that ducks your music, the climb before you hit it, warnings when a car is closing."
         case .story:
            "The ride still lives: map, traffic passes, speed, elevation, heart rate, the weather you rode through — and a GPX you can take with you."
         case .plus:
            "Thirty days of the whole cockpit — radar, turns, voice, climbs, Watch, the ride after. Then it stops unless you keep BigVelo. Past rides stay yours to view and export."
      }
   }

   /// Scannable brags. Empty on Keep BigVelo — pricing already fills that card.
   var highlights: [RideOnboardingHighlight] {
      switch self {
         case .kit:
            [
               .init(symbol: "iphone", text: "Phone on the bars — the computer"),
               .init(symbol: "applewatch", text: "Watch heart rate, no strap"),
               .init(symbol: "play.fill", text: "Start, pause and end from the wrist")
            ]
         case .radar:
            []
         case .ahead:
            [
               .init(symbol: "arrow.triangle.turn.up.right.diamond.fill", text: "Turn-by-turn on the phone"),
               .init(symbol: "speaker.wave.2.fill", text: "Spoken cues — your music stays"),
               .init(symbol: "chart.line.uptrend.xyaxis", text: "Elevation and the climb ahead"),
               .init(symbol: "exclamationmark.triangle.fill", text: "Radar warnings you can feel")
            ]
         case .story:
            [
               .init(symbol: "map", text: "The route, speed and elevation"),
               .init(symbol: "heart.fill", text: "Pulse, weather and every pass"),
               .init(symbol: "square.and.arrow.up", text: "Export GPX to take the ride with you")
            ]
         case .plus:
            []
      }
   }

   /// Garmin disclaimer lives under Continue, marked here with a superscript *.
   var showsGarminAffiliationNote: Bool { self == .radar }

   var plateName: String {
      switch self {
         case .kit: RideOnboardingArt.kit
         case .radar: RideOnboardingArt.radar
         case .ahead: RideOnboardingArt.story
         case .story: RideOnboardingArt.story
         case .plus: RideOnboardingArt.splash
      }
   }
}
