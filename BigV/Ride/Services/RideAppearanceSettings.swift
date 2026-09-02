//
//  RideAppearanceSettings.swift
//  BigV
//

import Foundation
import SwiftUI

/// How the cockpit is lit: follow the phone, or force day or night.
///
/// Night is the instrument look the app was drawn in. Day exists for the
/// rider squinting at a black screen in full sun: paper ground, black ink,
/// deepened accents, and the trail photos washed almost out.
enum RideAppearanceMode: String, CaseIterable, Identifiable, Sendable {
   case system
   case light
   case dark

   var id: String { rawValue }

   var title: String {
      switch self {
         case .system: "Automatic"
         case .light: "Day"
         case .dark: "Night"
      }
   }

   var detail: String {
      switch self {
         case .system: "Follows the phone’s appearance"
         case .light: "Paper and ink for riding in the sun"
         case .dark: "Graphite and instrument light"
      }
   }

   var symbolName: String {
      switch self {
         case .system: "circle.lefthalf.filled"
         case .light: "sun.max.fill"
         case .dark: "moon.fill"
      }
   }

   /// What to hand `preferredColorScheme`. `nil` lets the system decide.
   var colorScheme: ColorScheme? {
      switch self {
         case .system: nil
         case .light: .light
         case .dark: .dark
      }
   }
}

/// The rider's appearance preference, observable and persisted.
///
/// Same shape as `RideUnitsSettings`: UserDefaults cannot notify `@Observable`
/// tracking, so the value is a stored mirror loaded once and written through
/// on set.
@Observable
@MainActor
final class RideAppearanceSettings {

   // MARK: - Keys

   private enum Key {
      static let mode = "ride.appearance.mode"
   }

   @ObservationIgnored private let defaults: UserDefaults

   // MARK: - Preferences

   var mode: RideAppearanceMode {
      didSet { defaults.set(mode.rawValue, forKey: Key.mode) }
   }

   // MARK: - Initialization

   /// Night by default: a rider who has never touched the setting gets the
   /// cockpit exactly as it was before the switch existed.
   init(defaults: UserDefaults = .standard) {
      self.defaults = defaults
      mode = defaults.string(forKey: Key.mode).flatMap(RideAppearanceMode.init(rawValue:)) ?? .dark
   }

   // MARK: - Quick Switch

   /// The one-tap flip on the speedometer. It looks at what is actually on
   /// screen, so on Automatic it forces the opposite of the current light
   /// rather than cycling through a third state the rider did not ask for.
   func toggle(from resolved: ColorScheme) {
      mode = resolved == .dark ? .light : .dark
   }
}

// MARK: - Presentation

private struct RideAppearanceModifier: ViewModifier {

   @Environment(RideAppearanceSettings.self) private var appearanceSettings

   func body(content: Content) -> some View {
      content.preferredColorScheme(appearanceSettings.mode.colorScheme)
   }
}

extension View {

   /// Applies the rider's appearance choice to this presentation.
   ///
   /// Goes on the window root and on every sheet: a sheet is its own
   /// presentation, and without this it would follow the phone, not the rider.
   func rideAppearance() -> some View {
      modifier(RideAppearanceModifier())
   }
}
