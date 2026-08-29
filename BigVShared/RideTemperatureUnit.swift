//
//  RideTemperatureUnit.swift
//  BigVShared
//

import Foundation

/// The rider's temperature scale, kept apart from `RideUnitSystem`.
///
/// Weather is the only place BigV shows a temperature, and riders routinely
/// want imperial distance with a Celsius sky or the reverse, so binding this to
/// the measurement system would be wrong. Same persistence contract as
/// `RideUnitSystem`: one key, read as the formatter default. Fahrenheit when
/// unset — the app's default.
nonisolated enum RideTemperatureUnit: String, CaseIterable, Sendable, Identifiable, Codable {

   case fahrenheit
   case celsius

   var id: String { rawValue }

   // MARK: - Persistence

   static let defaultsKey = "ride.units.temperature"

   /// The scale currently in force on this device.
   static var current: RideTemperatureUnit {
      stored(in: .standard)
   }

   static func stored(in defaults: UserDefaults) -> RideTemperatureUnit {
      RideTemperatureUnit(rawValue: defaults.string(forKey: defaultsKey) ?? "") ?? .fahrenheit
   }

   // MARK: - Measurement

   var measurementUnit: UnitTemperature {
      switch self {
         case .fahrenheit: .fahrenheit
         case .celsius: .celsius
      }
   }

   /// Full suffix for the hero readout, where the scale has to be unambiguous.
   var suffix: String {
      switch self {
         case .fahrenheit: "°F"
         case .celsius: "°C"
      }
   }

   // MARK: - Setup Copy

   var title: String {
      switch self {
         case .fahrenheit: "Fahrenheit"
         case .celsius: "Celsius"
      }
   }

   var exampleText: String {
      switch self {
         case .fahrenheit: "72°F"
         case .celsius: "22°C"
      }
   }
}
