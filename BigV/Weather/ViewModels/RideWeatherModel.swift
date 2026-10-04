//
//  RideWeatherModel.swift
//  BigV
//

import CoreLocation
import Foundation
import Observation

/// The weather feature's single source of truth: where, what, and how often.
///
/// Owned by the app rather than by the status row, because a ride lasts hours
/// and the chip must not refetch every time the dashboard rebuilds or the rider
/// pages to the map. The detail sheet reads the same place and the same current
/// conditions, so pinning a city in the sheet moves the chip too.
@Observable
@MainActor
final class RideWeatherModel {

   // MARK: - Cadence
   //
   // A cycling computer runs lit for hours. The sky is not worth a network call
   // more often than this, and a failure backs off rather than hammering a
   // denied permission or a dead connection for the length of a ride.

   private static let refreshInterval: TimeInterval = 15 * 60
   private static let firstRetryInterval: TimeInterval = 30
   private static let maximumRetryInterval: TimeInterval = 10 * 60

   /// Degrees; matches the client's roughly one-kilometre cache cell.
   private static let matchTolerance = 0.02

   // MARK: - Published State

   private(set) var place: RideWeatherPlace?
   private(set) var snapshot: RideWeatherSnapshot?
   private(set) var isLoading = false
   private(set) var failureMessage: String?

   // MARK: - Dependencies

   /// Handed on to the detail sheet so both read one cache and one availability.
   @ObservationIgnored let weatherService: RideWeatherService

   @ObservationIgnored private let locationProbe: CurrentLocationProbe
   @ObservationIgnored private let unitsSettings: RideUnitsSettings

   // MARK: - Private State

   @ObservationIgnored private var lastAttemptAt: Date?
   @ObservationIgnored private var consecutiveFailures = 0
   @ObservationIgnored private var loadGeneration = 0

   // MARK: - Initialization

   init(
      weatherService: RideWeatherService = RideWeatherService(),
      locationProbe: CurrentLocationProbe = CurrentLocationProbe(),
      unitsSettings: RideUnitsSettings
   ) {
      self.weatherService = weatherService
      self.locationProbe = locationProbe
      self.unitsSettings = unitsSettings
      self.place = RideWeatherPlaceStore.pinnedPlace()
   }

   // MARK: - Derived

   /// Reading through to the settings keeps the scale live: flipping it in
   /// setup re-renders every temperature without touching the network.
   var temperatureUnit: RideTemperatureUnit { unitsSettings.temperatureUnit }

   var attributionURL: URL? { snapshot?.attributionLegalURL ?? weatherService.attributionLegalURL }

   var availability: RideWeatherAvailability { weatherService.availability }

   var placeLabel: String { place?.label ?? "Near you" }

   var isFollowingDevice: Bool { place?.isFollowingDevice ?? true }

   /// Only offered once the rider has pinned somewhere else.
   var canUseCurrentLocation: Bool { place?.source == .pinned }

   /// The chip has something worth a pill; otherwise it degrades to a glyph.
   var hasReading: Bool { displayedSnapshot != nil }

   /// The snapshot, only while it still describes the place on screen and is
   /// recent enough to trust. A failed refresh must not leave the last city's
   /// temperature under a new city's name, or an hours-old one on the chip.
   var displayedSnapshot: RideWeatherSnapshot? {
      guard let snapshot else { return nil }
      guard Date.now.timeIntervalSince(snapshot.fetchedAt) <= Self.refreshInterval * 2 else {
         return nil
      }
      if let place {
         guard abs(snapshot.latitude - place.latitude) < Self.matchTolerance,
               abs(snapshot.longitude - place.longitude) < Self.matchTolerance
         else { return nil }
      }
      return snapshot
   }

   // MARK: - Refresh Loop

   /// Driven by the chip's `task`, so it lives exactly as long as the dashboard
   /// is on screen and stops the moment SwiftUI tears the row down.
   func runRefreshLoop() async {
      while !Task.isCancelled {
         await refreshIfStale()

         try? await Task.sleep(for: .seconds(nextDelay))
      }
   }

   /// Safe to call on every scene activation: it no-ops while the reading is
   /// still fresh, so the caller never has to reason about cadence.
   func refreshIfStale() async {
      let elapsed = Date.now.timeIntervalSince(lastAttemptAt ?? .distantPast)
      guard elapsed >= (isRetrying ? retryInterval : Self.refreshInterval) else { return }

      await refresh()
   }

   // MARK: - Location Control

   func pin(coordinate: CLLocationCoordinate2D, label: String, timeZone: TimeZone? = nil) async {
      let pinned = RideWeatherPlace.pinned(coordinate: coordinate, label: label, timeZone: timeZone)
      RideWeatherPlaceStore.save(pinned)
      place = pinned
      resetReading()
      await refresh()
   }

   func useCurrentLocation() async {
      RideWeatherPlaceStore.clear()
      place = nil
      resetReading()
      await refresh()
   }

   /// The chip is the rider's first contact with the feature, so the prompt is
   /// raised from a tap rather than silently at launch.
   func requestLocationAuthorization() {
      locationProbe.requestAuthorizationIfNeeded()
   }

   // MARK: - Loading

   func refresh() async {
      let generation = beginLoad()

      guard let resolved = await resolvePlace() else {
         guard generation == loadGeneration else { return }

         // A cancelled probe says nothing about the permission, so it must not
         // be booked as a failure or push the backoff out.
         guard !Task.isCancelled else {
            abandonLoad()
            return
         }
         finish(generation: generation, snapshot: nil, message: Self.locationMessage)
         return
      }

      guard generation == loadGeneration else { return }
      place = resolved

      let reading = await weatherService.currentWeather(for: resolved.location)
      guard generation == loadGeneration else { return }

      if reading == nil, Task.isCancelled {
         abandonLoad()
         return
      }

      finish(
         generation: generation,
         snapshot: reading,
         message: reading == nil ? availability.riderMessage : nil
      )

      DebugPrint(
         mode: .weather,
         "Weather refreshed \(resolved.label) reading=\(reading != nil)"
      )
   }

   private func beginLoad() -> Int {
      loadGeneration += 1
      lastAttemptAt = .now
      isLoading = displayedSnapshot == nil
      return loadGeneration
   }

   /// A different place invalidates everything known about the last one.
   private func resetReading() {
      snapshot = nil
      failureMessage = nil
      consecutiveFailures = 0
      lastAttemptAt = nil
   }

   private func abandonLoad() {
      isLoading = false
      lastAttemptAt = nil
   }

   private func finish(generation: Int, snapshot reading: RideWeatherSnapshot?, message: String?) {
      guard generation == loadGeneration else { return }

      isLoading = false

      guard let reading else {
         consecutiveFailures += 1
         failureMessage = message ?? RideWeatherAvailability.unavailable.riderMessage
         return
      }

      consecutiveFailures = 0
      snapshot = reading
      failureMessage = nil
   }

   /// A pinned city wins; otherwise the GPS, named once and reused until the
   /// rider has moved far enough for the reading to be worth replacing.
   private func resolvePlace() async -> RideWeatherPlace? {
      if let place, place.source == .pinned { return place }

      guard let coordinate = await locationProbe.coordinate() else { return nil }

      let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
      let label = await RideWeatherPlaceResolver.localityLabel(for: location) ?? "Near you"

      return .device(coordinate: coordinate, label: label)
   }

   // MARK: - Backoff

   /// Backing off applies whenever the last attempt failed, even with an old
   /// snapshot on hand, and before the first reading has ever landed.
   private var isRetrying: Bool { consecutiveFailures > 0 || displayedSnapshot == nil }

   private var retryInterval: TimeInterval {
      let scaled = Self.firstRetryInterval * pow(2, Double(max(0, consecutiveFailures - 1)))
      return min(scaled, Self.maximumRetryInterval)
   }

   private var nextDelay: TimeInterval {
      isRetrying ? retryInterval : Self.refreshInterval
   }

   private static let locationMessage = "Location unavailable — allow location to see local weather."
}
