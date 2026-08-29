//
//  RideUnitsSettings.swift
//  BigV
//

import Foundation

/// The rider's measurement-system preference, observable and persisted.
///
/// Same shape as `RideRadarSettings`: UserDefaults cannot notify `@Observable`
/// tracking, so the value is a stored mirror loaded once and written through on
/// set. It writes the exact key `RideUnitSystem.current` reads, so every
/// formatter default and the Watch mirror pick the change up immediately.
@Observable
@MainActor
final class RideUnitsSettings {

   // MARK: - Keys

   private enum Key {
      static let setupCompleted = "ride.setup.completed"
   }

   @ObservationIgnored private let defaults: UserDefaults

   // MARK: - Preferences

   var system: RideUnitSystem {
      didSet { defaults.set(system.rawValue, forKey: RideUnitSystem.defaultsKey) }
   }

   /// Weather's scale, deliberately independent of `system`: riders ask for
   /// miles and Celsius often enough that tying the two would be wrong.
   var temperatureUnit: RideTemperatureUnit {
      didSet { defaults.set(temperatureUnit.rawValue, forKey: RideTemperatureUnit.defaultsKey) }
   }

   /// Set once the rider has been through first-run setup.
   var hasCompletedSetup: Bool {
      didSet { defaults.set(hasCompletedSetup, forKey: Key.setupCompleted) }
   }

   // MARK: - Initialization

   init(defaults: UserDefaults = .standard) {
      self.defaults = defaults
      system = RideUnitSystem.stored(in: defaults)
      temperatureUnit = RideTemperatureUnit.stored(in: defaults)
      hasCompletedSetup = defaults.bool(forKey: Key.setupCompleted)
   }
}
