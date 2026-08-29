//
//  RidePrecipForecast.swift
//  BigV
//

import Foundation

/// One column on the precipitation chart — an hour or a minute.
///
/// The distinction that earns its keep is `isWet`: a bar can carry a nonzero
/// chance and still be dry enough that drawing it as rain would mislead a rider
/// deciding whether to set off.
nonisolated struct RidePrecipBar: Identifiable, Equatable, Sendable {

   var id: Date { date }

   var date: Date
   var precipitationChance: Double
   var precipitationIntensity: Double

   /// Bar height comes from whichever of chance or intensity reads higher.
   var barFill: Double { max(precipitationIntensity, precipitationChance) }

   var isWet: Bool { precipitationIntensity > 0.08 || precipitationChance >= 0.2 }
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
               precipitationIntensity: hourlyIntensity(hour)
            )
         }
   }

   /// Snow and measurable rain both get a visible floor, so an hour forecast to
   /// drop snow can never draw shorter than one with a high chance and nothing
   /// actually falling.
   private static func hourlyIntensity(_ hour: RideWeatherHour) -> Double {
      let chance = hour.precipitationChance
      if hour.snowfallAmountMillimeters > 0 { return max(chance, 0.45) }

      let inches = hour.precipitationAmountMillimeters / 25.4
      if inches > 0 { return min(1, max(chance, 0.35 + min(inches, 0.5))) }

      return chance
   }

   static var hourlyTitle: String { "Next \(hourCount) Hours" }

   static func hourlySummary(bars: [RidePrecipBar], now: Date = .now) -> String {
      guard let firstWet = bars.first(where: \.isWet) else { return "No precipitation expected" }

      let start = bars.first?.date ?? now
      if Calendar.current.isDate(firstWet.date, equalTo: start, toGranularity: .hour) {
         return "Rain now"
      }

      return "Rain starting around \(hourLabel(for: firstWet.date))"
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
               precipitationIntensity: $0.precipitationIntensity
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

         return RidePrecipBar(
            date: date,
            precipitationChance: chance,
            precipitationIntensity: chance
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
