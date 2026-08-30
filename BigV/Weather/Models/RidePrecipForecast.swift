//
//  RidePrecipForecast.swift
//  BigV
//

import Foundation

/// What a bar's height means. Height and caption must encode the same quantity
/// or the chart lies: the hourly chart prints a percentage, so it has to be
/// drawn from the chance, while the minute chart prints nothing and is free to
/// draw the rate.
nonisolated enum RidePrecipMetric: Sendable, Equatable {
   case chance
   case intensity
}

/// One column on the precipitation chart — an hour or a minute.
///
/// The distinction that earns its keep is `isWet`: a bar can carry a nonzero
/// chance and still be dry enough that drawing it as rain would mislead a rider
/// deciding whether to set off.
nonisolated struct RidePrecipBar: Identifiable, Equatable, Sendable {

   var id: Date { date }

   var date: Date

   /// 0…1 probability of precipitation — the number the caption prints.
   var precipitationChance: Double

   /// 0…1 normalised rate. Drives colour and the wet test, never the height of
   /// a captioned bar.
   var precipitationIntensity: Double

   /// Millimetres forecast for the hour. A trace is not rain.
   var precipitationAmountMillimeters: Double = 0

   var metric: RidePrecipMetric = .chance

   /// Share of the plot this bar fills, on an absolute 0…1 scale. A 40% chance
   /// draws at 40% height, so the caption and the geometry cannot disagree and
   /// a flat afternoon reads as flat instead of being stretched to fill.
   var barFill: Double {
      switch metric {
         case .chance: min(1, max(0, precipitationChance))
         case .intensity: min(1, max(0, precipitationIntensity))
      }
   }

   var isWet: Bool {
      switch metric {
         case .chance:
            precipitationChance >= RidePrecipForecast.wetChance
               || precipitationAmountMillimeters >= RidePrecipForecast.wetMillimeters

         case .intensity:
            precipitationIntensity >= RidePrecipForecast.wetIntensity
      }
   }
}

/// Turns forecast snapshots into chart bars and the sentences that caption them.
///
/// Pure and free of SwiftUI on purpose: these rules decide whether a rider reads
/// "rain starting around 4p" before rolling out, which deserves to be testable
/// rather than eyeballed.
nonisolated enum RidePrecipForecast {

   // MARK: - Tuning

   static let hourCount = 12
   static let nextHourDuration: TimeInterval = 60 * 60

   /// Below a one-in-four chance, calling an hour wet turns a mostly dry
   /// forecast into a warning the rider will learn to ignore.
   static let wetChance = 0.25

   /// The WMO trace cutoff: under 0.2 mm nothing measurable reaches the road.
   static let wetMillimeters = 0.2

   static let wetIntensity = 0.08

   /// Heavy rain in mm/hr, used as full scale when mapping an amount onto 0…1.
   static let heavyRainMillimetersPerHour = 7.6

   // MARK: - Hourly

   static func hourlyBars(
      hours: [RideWeatherHour],
      anchor: Date,
      limit: Int = hourCount
   ) -> [RidePrecipBar] {
      let calendar = Calendar.current
      let startOfHour = calendar.date(
         from: calendar.dateComponents([.year, .month, .day, .hour], from: anchor)
      ) ?? anchor

      return hours
         .lazy
         .filter { $0.date >= startOfHour }
         .prefix(limit)
         .map { hour in
            RidePrecipBar(
               date: hour.date,
               precipitationChance: hour.precipitationChance,
               precipitationIntensity: hourlyIntensity(hour),
               precipitationAmountMillimeters: hourlyMillimeters(hour),
               metric: .chance
            )
         }
   }

   private static func hourlyMillimeters(_ hour: RideWeatherHour) -> Double {
      hour.precipitationAmountMillimeters + hour.snowfallAmountMillimeters
   }

   /// Forecast millimetres mapped onto 0…1 for colour and the wet test only.
   /// Nothing here may reach the bar height: the caption prints a percentage,
   /// and an hour holding a trace of rain must not out-draw a 60% chance.
   private static func hourlyIntensity(_ hour: RideWeatherHour) -> Double {
      min(1, hourlyMillimeters(hour) / heavyRainMillimetersPerHour)
   }

   static var hourlyTitle: String { "Next \(hourCount) Hours" }

   static func hourlySummary(bars: [RidePrecipBar], now: Date = .now) -> String {
      guard let firstWet = bars.first(where: \.isWet) else {
         return dryHourlySummary(bars: bars)
      }

      let start = bars.first?.date ?? now
      if Calendar.current.isDate(firstWet.date, equalTo: start, toGranularity: .hour) {
         return "Rain now"
      }

      return "Rain starting around \(hourLabel(for: firstWet.date))"
   }

   /// Naming the peak explains the short bars instead of leaving a rider to
   /// wonder what a chart of 4% columns is trying to say.
   private static func dryHourlySummary(bars: [RidePrecipBar]) -> String {
      let peak = bars.map(\.precipitationChance).max() ?? 0
      guard peak >= 0.01 else { return "No precipitation expected" }

      return "No rain expected — chance peaks at \(percentLabel(peak))"
   }

   /// Label every other bar plus the last, so twelve columns stay readable.
   static func hourlyAxisMarkers(for bars: [RidePrecipBar]) -> [RidePrecipAxisMarker] {
      guard !bars.isEmpty else { return [] }

      let count = Double(bars.count)
      return bars.enumerated().compactMap { index, bar in
         guard index.isMultiple(of: 2) || index == bars.count - 1 else { return nil }
         return RidePrecipAxisMarker(
            label: hourLabel(for: bar.date),
            fraction: (Double(index) + 0.5) / count
         )
      }
   }

   // MARK: - Minutes

   static let minuteAxisMarkers: [RidePrecipAxisMarker] = [
      RidePrecipAxisMarker(label: "Now", fraction: 0.02),
      RidePrecipAxisMarker(label: "10m", fraction: 0.18),
      RidePrecipAxisMarker(label: "20m", fraction: 0.34),
      RidePrecipAxisMarker(label: "30m", fraction: 0.50),
      RidePrecipAxisMarker(label: "40m", fraction: 0.66),
      RidePrecipAxisMarker(label: "50m", fraction: 0.82)
   ]

   /// The next hour minute by minute, falling back to the hourly chance where
   /// Apple publishes no minute forecast — which is most of the world.
   static func minuteBars(
      minutes: [RideWeatherMinute],
      hourlyFallback: [RideWeatherHour],
      now: Date = .now
   ) -> [RidePrecipBar] {
      let end = now.addingTimeInterval(nextHourDuration)

      let live = minutes
         .filter { $0.date >= now && $0.date < end }
         .map {
            RidePrecipBar(
               date: $0.date,
               precipitationChance: $0.precipitationChance,
               precipitationIntensity: $0.precipitationIntensity,
               metric: .intensity
            )
         }
      if !live.isEmpty { return live }

      return (0..<60).compactMap { offset in
         let date = now.addingTimeInterval(TimeInterval(offset * 60))
         guard date < end else { return nil }

         let hour = hourlyFallback.first {
            $0.date <= date && $0.date.addingTimeInterval(3600) > date
         }
         let chance = hour?.precipitationChance ?? 0

         // No minute forecast here, so the only honest quantity is the hour's
         // chance — carried as a chance rather than dressed up as a rate.
         return RidePrecipBar(
            date: date,
            precipitationChance: chance,
            precipitationIntensity: 0,
            precipitationAmountMillimeters: hour?.precipitationAmountMillimeters ?? 0,
            metric: .chance
         )
      }
   }

   static func nextHourTitle(minuteBars: [RidePrecipBar]) -> String {
      guard let first = minuteBars.first else { return "Next Hour" }
      if first.isWet { return "Raining Now" }
      if minuteBars.contains(where: \.isWet) { return "Rain Forecast" }
      return "No Rain"
   }

   /// Deliberately concrete — "in 12 min" changes what a rider does in a way
   /// that "precipitation likely" does not.
   static func nextHourSummary(minuteBars: [RidePrecipBar], now: Date = .now) -> String {
      guard let first = minuteBars.first else { return "No minute data available." }

      if first.isWet {
         if let stop = minuteBars.first(where: { !$0.isWet }) {
            let minutes = max(1, Int(stop.date.timeIntervalSince(now) / 60))
            return "Rain is expected to stop in \(minutes) min."
         }
         return "Rain is expected to continue for the next hour."
      }

      guard let start = minuteBars.first(where: \.isWet) else {
         return "No rain expected in the next hour."
      }

      let startMinutes = max(1, Int(start.date.timeIntervalSince(now) / 60))
      let wet = minuteBars.filter { $0.date >= start.date && $0.isWet }

      if let last = wet.last, last.date > start.date {
         let duration = max(1, Int(last.date.timeIntervalSince(start.date) / 60) + 1)
         return "Rain is expected to start in \(startMinutes) min, lasting \(duration) min."
      }

      return "Rain is expected to start in \(startMinutes) min."
   }

   // MARK: - Labels

   static func percentLabel(_ fraction: Double) -> String {
      "\(Int((min(1, max(0, fraction)) * 100).rounded()))%"
   }

   static func hourLabel(for date: Date) -> String {
      date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
         .lowercased()
         .replacingOccurrences(of: "m", with: "")
         .replacingOccurrences(of: " ", with: "")
   }
}

/// A tick under the precipitation chart, positioned as a fraction of its width.
nonisolated struct RidePrecipAxisMarker: Identifiable, Equatable, Sendable {

   var id: String { "\(label)-\(fraction)" }

   let label: String
   let fraction: Double
}
