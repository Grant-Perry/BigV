//
//  RideDetailViewModel.swift
//  BigV
//

import Foundation
import SwiftData

/// Builds everything the ride detail screen shows for one saved ride.
///
/// Reads the stored row once and projects it into display-ready reports:
/// route, headline numbers, elevation and speed profiles, the heart rate
/// story, the sky it was ridden under and the traffic behind. Heart rate
/// prefers the ride's own samples and falls back to Apple Health, so rides
/// recorded before samples carried a pulse still get their chart.
@Observable
@MainActor
final class RideDetailViewModel {

   // MARK: - State

   private(set) var isLoaded = false
   private(set) var titleText = ""

   private(set) var route = RideRoute.empty
   private(set) var radarPasses: [RideRadarPassAnnotation] = []

   private(set) var header: RideDetailHeader?
   private(set) var elevation: RideElevationReport?
   private(set) var speed: RideSpeedReport?
   private(set) var heartRate: RideHeartRateReport?
   private(set) var weather: RideDetailWeatherReport?
   private(set) var radar: RideRadarReport?
   private(set) var laps: RideLapsReport?

   /// Ready after load when the ride has a drawable track. Share from the
   /// detail toolbar — this is the GPX other apps can open, not the JSON backup.
   private(set) var gpxShareURL: URL?

   // MARK: - Dependencies

   /// Both optional so previews can build the screen with no store or Health
   /// behind it, matching how `RideSessionManager` treats its dependencies.
   private let rideStorageManager: RideStorageManager?
   private let vitalsReader: RideHealthVitalsReader?

   // MARK: - Initialization

   init(
      rideStorageManager: RideStorageManager? = nil,
      vitalsReader: RideHealthVitalsReader? = nil
   ) {
      self.rideStorageManager = rideStorageManager
      self.vitalsReader = vitalsReader
   }

   // MARK: - Intent

   func load(_ identifier: PersistentIdentifier?) async {
      guard let identifier,
            let ride = rideStorageManager?.ride(with: identifier)
      else {
         reset()
         isLoaded = true
         return
      }

      let system = RideUnitSystem.current
      let samples = ride.samples.sorted { $0.timestamp < $1.timestamp }

      route = RideRoute(coordinates: RideRouteDownsampler.route(from: samples))
      radarPasses = Self.passAnnotations(from: ride)
      titleText = ride.startDate.formatted(date: .abbreviated, time: .shortened)

      header = Self.header(for: ride, system: system)
      elevation = RideChartSeriesBuilder.elevationReport(for: ride, samples: samples, system: system)
      speed = RideChartSeriesBuilder.speedReport(for: ride, samples: samples, system: system)
      weather = Self.weatherReport(for: ride)
      radar = RideChartSeriesBuilder.radarReport(for: ride, system: system)
      heartRate = RideChartSeriesBuilder.heartRateReport(for: ride, samples: samples)
      laps = RideLapsReportBuilder.report(for: ride, system: system)
      gpxShareURL = Self.writeGPXFile(ride: ride, samples: samples, title: titleText)
      isLoaded = true

      await enrichFromHealth(ride)
   }

   func clear() {
      reset()
      isLoaded = false
   }

   private func reset() {
      route = .empty
      radarPasses = []
      titleText = ""
      header = nil
      elevation = nil
      speed = nil
      heartRate = nil
      weather = nil
      radar = nil
      laps = nil
      gpxShareURL = nil
   }

   // MARK: - GPX

   private static func writeGPXFile(
      ride: Ride,
      samples: [RideSample],
      title: String
   ) -> URL? {
      let points = samples.map {
         RideGPXExporter.Point(
            timestamp: $0.timestamp,
            latitude: $0.latitude,
            longitude: $0.longitude,
            altitude: $0.altitude
         )
      }
      let name = ride.name.isEmpty ? title : ride.name

      do {
         let data = try RideGPXExporter.data(name: name, startDate: ride.startDate, points: points)
         let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(RideGPXExporter.fileName(startDate: ride.startDate))
         try data.write(to: url, options: .atomic)
         return url
      } catch {
         DebugPrint(mode: .persistence, "GPX export failed: \(error.localizedDescription)")
         return nil
      }
   }

   // MARK: - Apple Health Enrichment

   /// Fills whatever the stored ride could not: a pulse series for rides whose
   /// samples carry none, and calories, which only Health ever measured.
   private func enrichFromHealth(_ ride: Ride) async {
      guard let vitalsReader else { return }

      let needsPulse = heartRate == nil
      let needsCalories = heartRate?.caloriesText == nil && ride.activeEnergy == nil
      guard needsPulse || needsCalories else { return }

      let start = ride.startDate
      let end = ride.endDate ?? start.addingTimeInterval(ride.duration)
      let expectedTitle = titleText

      guard let vitals = await vitalsReader.vitals(from: start, to: end) else { return }

      // The rider may have navigated to another ride while Health answered.
      guard titleText == expectedTitle else { return }

      let calories = ride.activeEnergy ?? vitals.activeEnergyKilocalories

      if let existing = heartRate {
         heartRate = RideChartSeriesBuilder.withCalories(calories, applied: existing)
      } else if !vitals.heartBeats.isEmpty {
         heartRate = RideChartSeriesBuilder.heartRateReport(
            beats: vitals.heartBeats.map { ($0.timestamp, $0.beatsPerMinute) },
            startDate: start,
            calories: calories,
            isFromAppleHealth: true
         )
      } else if let calories {
         // Calories without a pulse still deserve a home on the health card.
         heartRate = RideHeartRateReport(
            points: [],
            averageText: RideFormatters.placeholder,
            maximumText: RideFormatters.placeholder,
            minimumText: RideFormatters.placeholder,
            maximumPoint: nil,
            minimumPoint: nil,
            caloriesText: RideChartSeriesBuilder.caloriesText(calories),
            isFromAppleHealth: true
         )
      }
   }

   // MARK: - Header

   private static func header(for ride: Ride, system: RideUnitSystem) -> RideDetailHeader {
      let end = ride.endDate ?? ride.startDate.addingTimeInterval(ride.duration)
      let stopped = max(0, ride.duration - ride.movingTime)

      return RideDetailHeader(
         dateText: ride.startDate.formatted(date: .complete, time: .omitted),
         timeRangeText: "\(ride.startDate.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))",
         distance: RideFormatters.distance(ride.distance, system: system),
         distanceUnit: system.distanceUnit,
         rideTime: RideFormatters.duration(ride.duration),
         movingTime: RideFormatters.duration(ride.movingTime),
         stoppedTime: RideFormatters.duration(stopped),
         averageSpeed: RideFormatters.speed(ride.averageSpeed, system: system),
         speedUnit: system.speedUnit
      )
   }

   // MARK: - Weather

   private static func weatherReport(for ride: Ride) -> RideDetailWeatherReport? {
      guard let symbolName = ride.weatherSymbolName,
            let startCelsius = ride.startTemperatureCelsius
      else { return nil }

      let startText = RideFormatters.temperatureDegrees(startCelsius)

      var temperatureText = startText
      if let endCelsius = ride.endTemperatureCelsius {
         let endText = RideFormatters.temperatureDegrees(endCelsius)
         if endText != startText {
            temperatureText = "\(startText) → \(endText)"
         }
      }

      var feelsLikeText: String?
      if let apparent = ride.startApparentTemperatureCelsius {
         let apparentText = RideFormatters.temperatureDegrees(apparent)
         if apparentText != startText {
            feelsLikeText = "Feels \(apparentText)"
         }
      }

      return RideDetailWeatherReport(
         symbolName: symbolName,
         conditionLabel: ride.weatherConditionLabel ?? "",
         temperatureText: temperatureText,
         feelsLikeText: feelsLikeText,
         windText: windText(ride.windSpeedKilometersPerHour)
      )
   }

   private static func windText(_ kilometersPerHour: Double?) -> String? {
      guard let kilometersPerHour, kilometersPerHour >= 1 else { return nil }

      let system = RideUnitSystem.current
      let value = system == .imperial ? kilometersPerHour * 0.621371 : kilometersPerHour
      let unit = system == .imperial ? "mph" : "km/h"
      return "\(value.formatted(.number.precision(.fractionLength(0)))) \(unit) wind"
   }

   // MARK: - Map Passes

   /// Passes recorded before the first GPS fix have no coordinate; they count
   /// in the totals but cannot be placed on the map.
   private static func passAnnotations(from ride: Ride) -> [RideRadarPassAnnotation] {
      ride.radarEvents
         .sorted { $0.timestamp < $1.timestamp }
         .enumerated()
         .compactMap { index, event in
            guard let latitude = event.latitude, let longitude = event.longitude else {
               return nil
            }
            return RideRadarPassAnnotation(
               id: index,
               latitude: latitude,
               longitude: longitude,
               tier: event.peakTier
            )
         }
   }
}
