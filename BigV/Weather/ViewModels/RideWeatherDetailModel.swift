//
//  RideWeatherDetailModel.swift
//  BigV
//

import CoreLocation
import Foundation
import Observation

/// The weather sheet's own state: the forecast depth the chip never needs.
///
/// Current conditions stay on `RideWeatherModel`, which the chip already keeps
/// warm, so opening the sheet costs one daily and one precipitation call rather
/// than a full reload. Place changes are delegated upward — a city pinned here
/// is the city the dashboard reads.
@Observable
@MainActor
final class RideWeatherDetailModel {

   // MARK: - Published State

   private(set) var daily: [RideWeatherDay] = []
   private(set) var precipOutlook: RidePrecipOutlook = .empty
   private(set) var isLoading = false

   // MARK: - Dependencies

   @ObservationIgnored private let weatherModel: RideWeatherModel
   @ObservationIgnored private let weatherService: RideWeatherService

   // MARK: - Private State

   @ObservationIgnored private var loadGeneration = 0

   // MARK: - Initialization

   init(weatherModel: RideWeatherModel) {
      self.weatherModel = weatherModel
      self.weatherService = weatherModel.weatherService
   }

   // MARK: - Derived

   var placeLabel: String { weatherModel.placeLabel }

   var coordinate: CLLocationCoordinate2D {
      weatherModel.place?.coordinate ?? Self.fallbackCoordinate
   }

   var current: RideWeatherSnapshot? { weatherModel.snapshot }

   var temperatureUnit: RideTemperatureUnit { weatherModel.temperatureUnit }

   var attributionURL: URL? { weatherModel.attributionURL }

   var failureMessage: String? { weatherModel.failureMessage }

   var isFollowingDevice: Bool { weatherModel.isFollowingDevice }

   var canUseCurrentLocation: Bool { weatherModel.canUseCurrentLocation }

   var hasPlace: Bool { weatherModel.place != nil }

   /// Today's row, which carries the sun times and the high/low the hero shows
   /// when the current conditions do not.
   var today: RideWeatherDay? {
      let calendar = Calendar.current
      return daily.first { calendar.isDateInToday($0.calendarDayStart) } ?? daily.first
   }

   // MARK: - Loading

   func load() async {
      loadGeneration += 1
      let generation = loadGeneration
      isLoading = daily.isEmpty && precipOutlook.isEmpty

      await weatherModel.refreshIfStale()
      guard generation == loadGeneration, let place = weatherModel.place else {
         isLoading = false
         return
      }

      async let forecast = weatherService.dailyForecast(for: place.location)
      async let outlook = weatherService.precipOutlook(for: place.location)

      let days = await forecast
      let precipitation = await outlook
      guard generation == loadGeneration else { return }

      daily = days
      precipOutlook = precipitation
      isLoading = false

      DebugPrint(
         mode: .weather,
         "Weather detail loaded \(place.label) days=\(days.count) hours=\(precipitation.hours.count)"
      )
   }

   // MARK: - Location

   func selectPlace(coordinate: CLLocationCoordinate2D, label: String) async {
      clearForecast()
      await weatherModel.pin(coordinate: coordinate, label: label)
      await load()
   }

   func useCurrentLocation() async {
      clearForecast()
      weatherModel.requestLocationAuthorization()
      await weatherModel.useCurrentLocation()
      await load()
   }

   /// The old city's forecast must not sit under the new city's name while the
   /// replacement is in flight.
   private func clearForecast() {
      loadGeneration += 1
      daily = []
      precipOutlook = .empty
      isLoading = true
   }

   /// Only ever seen for the instant before a place resolves, and never
   /// rendered with data attached.
   private static let fallbackCoordinate = CLLocationCoordinate2D(
      latitude: 37.334_886,
      longitude: -122.008_988
   )
}
