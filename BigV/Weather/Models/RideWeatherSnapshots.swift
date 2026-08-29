//
//  RideWeatherSnapshots.swift
//  BigV
//

import Foundation

// MARK: - Availability

/// Why weather is or is not on screen.
///
/// Each case earns its own words because each needs a different answer from the
/// rider: `notEntitled` is a build they cannot fix, `offline` clears when signal
/// returns, `rateLimited` clears on its own, and `unavailable` is everything
/// WeatherKit refused to explain.
nonisolated enum RideWeatherAvailability: String, Sendable, Equatable {

   case unknown
   case ready
   case notEntitled
   case offline
   case rateLimited
   case unavailable

   var riderMessage: String {
      switch self {
         case .unknown: "Checking the sky…"
         case .ready: ""
         case .notEntitled: "Weather is not enabled for this build."
         case .offline: "No connection — weather will update when you're back online."
         case .rateLimited: "Too many weather requests — trying again shortly."
         case .unavailable: "Weather unavailable right now."
      }
   }
}

// MARK: - Current

/// Conditions at one place at one moment.
///
/// Every temperature is stored in Celsius because WeatherKit is metric at the
/// source; `RideFormatters` is the only place that converts to the rider's
/// scale, so a unit change re-renders without refetching.
nonisolated struct RideWeatherSnapshot: Sendable, Equatable, Hashable {

   var latitude: Double
   var longitude: Double
   var fetchedAt: Date
   var conditionSymbolName: String
   var conditionLabel: String
   var temperatureCelsius: Double
   var apparentTemperatureCelsius: Double?
   var highCelsius: Double?
   var lowCelsius: Double?
   var precipitationChance: Double?
   var windSpeedKilometersPerHour: Double?
   var attributionLegalURL: URL?

   var symbolName: String {
      RideWeatherSymbols.resolve(
         symbolName: conditionSymbolName,
         conditionLabel: conditionLabel
      )
   }
}

// MARK: - Day

nonisolated struct RideWeatherDay: Sendable, Equatable, Hashable, Identifiable {

   var id: Date { calendarDayStart }

   var calendarDayStart: Date
   var conditionSymbolName: String
   var conditionLabel: String
   var highCelsius: Double
   var lowCelsius: Double
   var precipitationChance: Double
   var sunrise: Date?
   var sunset: Date?
   var uvIndex: Int?

   var symbolName: String {
      RideWeatherSymbols.resolve(
         symbolName: conditionSymbolName,
         conditionLabel: conditionLabel
      )
   }
}

// MARK: - Hour

nonisolated struct RideWeatherHour: Sendable, Equatable, Hashable, Identifiable {

   var id: Date { date }

   var date: Date
   var conditionSymbolName: String
   var conditionLabel: String
   var temperatureCelsius: Double
   var precipitationChance: Double
   var precipitationAmountMillimeters: Double
   var snowfallAmountMillimeters: Double

   var symbolName: String {
      RideWeatherSymbols.resolve(
         symbolName: conditionSymbolName,
         conditionLabel: conditionLabel
      )
   }
}

// MARK: - Minute

/// One minute of the next-hour forecast.
///
/// `precipitationIntensity` arrives normalised to 0…1 rather than in mm/hr: the
/// only consumer is a bar height, and normalising at the fetch keeps the unit
/// conversion in one place.
nonisolated struct RideWeatherMinute: Sendable, Equatable, Hashable, Identifiable {

   var id: Date { date }

   var date: Date
   var precipitationChance: Double
   var precipitationIntensity: Double
}

// MARK: - Outlook

/// Hourly and minute precipitation for one place, fetched together.
///
/// One WeatherKit round trip rather than two, because the precip card flips
/// between the two views on tap and a rider must not wait on a second call to
/// see the chart move. `minutes` is empty wherever Apple publishes no minute
/// forecast, which is most of the world.
nonisolated struct RidePrecipOutlook: Sendable, Equatable {

   var hours: [RideWeatherHour]
   var minutes: [RideWeatherMinute]

   static let empty = RidePrecipOutlook(hours: [], minutes: [])

   var isEmpty: Bool { hours.isEmpty && minutes.isEmpty }
}

// MARK: - Symbols

nonisolated enum RideWeatherSymbols {

   /// WeatherKit's own symbol when it gave one, a condition-text match when it
   /// did not. Never an empty string, which renders as a hole in the row.
   static func resolve(symbolName: String, conditionLabel: String) -> String {
      symbolName.isEmpty ? fallback(forConditionLabel: conditionLabel) : symbolName
   }

   static func fallback(forConditionLabel label: String) -> String {
      let lower = label.lowercased()

      if lower.contains("thunder") { return "cloud.bolt.rain.fill" }
      if lower.contains("snow") || lower.contains("sleet") || lower.contains("blizzard") {
         return "cloud.snow.fill"
      }
      if lower.contains("rain") || lower.contains("drizzle") || lower.contains("shower") {
         return "cloud.rain.fill"
      }
      if lower.contains("fog") || lower.contains("haze") || lower.contains("smoke") {
         return "cloud.fog.fill"
      }
      if lower.contains("cloud") || lower.contains("overcast") { return "cloud.fill" }
      if lower.contains("wind") { return "wind" }
      if lower.contains("clear") || lower.contains("sun") || lower.contains("fair") {
         return "sun.max.fill"
      }

      return "cloud.sun.fill"
   }
}
