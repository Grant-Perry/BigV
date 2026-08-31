//
//  RideClimbSettings.swift
//  BigV
//

import Foundation

/// The rider's climb-page preference, observable and persisted.
///
/// Same shape as `RideRadarSettings`: UserDefaults cannot notify `@Observable`
/// tracking, so the value is a stored mirror loaded once and written through
/// on set.
@Observable
@MainActor
final class RideClimbSettings {

   // MARK: - Keys

   private enum Key {
      static let autoSwitch = "climb.autoSwitch.enabled"
   }

   @ObservationIgnored private let defaults: UserDefaults

   // MARK: - Preferences

   /// Whether starting a categorized climb pages the cockpit from the
   /// dashboard to the climb screen. On by default — it is the feature's whole
   /// point — with the off switch for riders who page by hand.
   var autoSwitchEnabled: Bool {
      didSet { defaults.set(autoSwitchEnabled, forKey: Key.autoSwitch) }
   }

   // MARK: - Initialization

   init(defaults: UserDefaults = .standard) {
      self.defaults = defaults
      autoSwitchEnabled = defaults.object(forKey: Key.autoSwitch) as? Bool ?? true
   }
}
