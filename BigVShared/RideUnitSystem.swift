//
//  RideUnitSystem.swift
//  BigVShared
//

import Foundation

/// The rider's measurement system, driving every displayed figure app-wide.
///
/// Persisted under one UserDefaults key that `RideFormatters` reads as its
/// default, so the engine can stay SI everywhere and conversion stays in one
/// place. Imperial when unset — the app's default. The Watch never reads this
/// key; the phone's choice rides the metrics snapshot instead.
nonisolated enum RideUnitSystem: String, CaseIterable, Sendable, Identifiable, Codable {

   case imperial
   case metric

   var id: String { rawValue }

   // MARK: - Persistence

   static let defaultsKey = "ride.units"

   /// The system currently in force on this device.
   static var current: RideUnitSystem {
      stored(in: .standard)
   }

   static func stored(in defaults: UserDefaults) -> RideUnitSystem {
      RideUnitSystem(rawValue: defaults.string(forKey: defaultsKey) ?? "") ?? .imperial
   }

   // MARK: - Unit Labels

   var speedUnit: String {
      switch self {
         case .imperial: "MPH"
         case .metric: "KM/H"
      }
   }

   var distanceUnit: String {
      switch self {
         case .imperial: "MI"
         case .metric: "KM"
      }
   }

   var elevationUnit: String {
      switch self {
         case .imperial: "FT"
         case .metric: "M"
      }
   }

   // MARK: - Setup Copy

   var title: String {
      switch self {
         case .imperial: "Imperial"
         case .metric: "Metric"
      }
   }

   var exampleText: String {
      switch self {
         case .imperial: "mph · miles · feet"
         case .metric: "km/h · kilometers · meters"
      }
   }
}
