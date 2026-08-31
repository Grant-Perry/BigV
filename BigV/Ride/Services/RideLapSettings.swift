//
//  RideLapSettings.swift
//  BigV
//

import Foundation

/// The rider's auto-lap preference, observable and persisted.
///
/// The value is a count of the rider's own distance units — "every 5" means
/// five miles or five kilometers, whichever the app is set to — so switching
/// measurement systems keeps the intent rather than a stranded metric number.
/// Zero is off, matching the Garmin convention.
@Observable
@MainActor
final class RideLapSettings {

   // MARK: - Keys

   private enum Key {
      static let autoLapUnits = "lap.auto.units"
   }

   /// The choices Settings offers. Free-typing a lap distance on a bike
   /// computer is fiddle for no benefit; these cover how riders actually lap.
   static let autoLapChoices: [Double] = [0, 1, 5, 10, 25]

   @ObservationIgnored private let defaults: UserDefaults

   // MARK: - Preferences

   /// Auto-lap every this many miles/kilometers. `0` is off.
   var autoLapUnits: Double {
      didSet { defaults.set(autoLapUnits, forKey: Key.autoLapUnits) }
   }

   // MARK: - Derived

   /// The trigger distance in meters under the current unit system, or `nil`
   /// when auto-lap is off.
   var autoLapDistanceMeters: Double? {
      guard autoLapUnits > 0 else { return nil }
      let unitLength: Double = RideUnitSystem.current == .imperial ? 1_609.344 : 1_000
      return autoLapUnits * unitLength
   }

   // MARK: - Initialization

   init(defaults: UserDefaults = .standard) {
      self.defaults = defaults
      autoLapUnits = defaults.double(forKey: Key.autoLapUnits)
   }
}
