//
//  RideWeatherService.swift
//  BigV
//

import CoreLocation
import Foundation
import Observation
import WeatherKit

// MARK: - Client

/// Off-main WeatherKit I/O with per-coordinate caching and request coalescing.
///
/// An actor rather than a main-actor type because the JWT handshake and the
/// network round trip are the two slowest things the weather feature does, and
/// a cycling dashboard renders at speed with the screen lit — neither may ever
/// land on the UI thread.
actor RideWeatherClient {

   static let shared = RideWeatherClient()

   // MARK: - Freshness
   //
   // A ride runs for hours with the display on, so the ceiling on how often
   // WeatherKit may be asked lives here rather than in a caller's timer. The
   // sky does not move fast enough to justify anything shorter.

   private let currentTTL: TimeInterval = 15 * 60
   private let dailyTTL: TimeInterval = 60 * 60
   private let outlookTTL: TimeInterval = 10 * 60

   // MARK: - State

   private let weatherService = WeatherService.shared

   private var availability: RideWeatherAvailability = .unknown
   private var attributionLegalURL: URL?

   private var currentCache: [String: (snapshot: RideWeatherSnapshot, expires: Date)] = [:]
   private var dailyCache: [String: (days: [RideWeatherDay], expires: Date)] = [:]
   private var outlookCache: [String: (outlook: RidePrecipOutlook, expires: Date)] = [:]

   private var currentInFlight: [String: Task<RideWeatherSnapshot?, Never>] = [:]
   private var dailyInFlight: [String: Task<[RideWeatherDay], Never>] = [:]
   private var outlookInFlight: [String: Task<RidePrecipOutlook, Never>] = [:]

   // MARK: - Metadata

   func currentAvailability() -> RideWeatherAvailability { availability }

   func currentAttributionURL() -> URL? { attributionLegalURL }

   // MARK: - Current

   func currentWeather(for location: CLLocation) async -> RideWeatherSnapshot? {
      let key = Self.cacheKey(for: location.coordinate)

      if let cached = currentCache[key], cached.expires > .now { return cached.snapshot }
      if let existing = currentInFlight[key] { return await existing.value }

      let task = Task { await fetchCurrent(for: location, cacheKey: key) }
      currentInFlight[key] = task
      let snapshot = await task.value
      currentInFlight[key] = nil

      return snapshot
   }

   private func fetchCurrent(
      for location: CLLocation,
      cacheKey: String
   ) async -> RideWeatherSnapshot? {
      do {
         let (current, daily) = try await weatherService.weather(
            for: location,
            including: .current, .daily
         )
         let today = daily.forecast.first
         await refreshAttribution()

         let snapshot = RideWeatherSnapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            fetchedAt: .now,
            conditionSymbolName: current.symbolName,
            conditionLabel: current.condition.description,
            temperatureCelsius: current.temperature.converted(to: .celsius).value,
            apparentTemperatureCelsius: current.apparentTemperature.converted(to: .celsius).value,
            highCelsius: today?.highTemperature.converted(to: .celsius).value,
            lowCelsius: today?.lowTemperature.converted(to: .celsius).value,
            precipitationChance: today?.precipitationChance,
            windSpeedKilometersPerHour: current.wind.speed
               .converted(to: .kilometersPerHour).value,
            attributionLegalURL: attributionLegalURL
         )

         availability = .ready
         currentCache[cacheKey] = (snapshot, Date.now.addingTimeInterval(currentTTL))
         return snapshot
      } catch {
         record(error, stage: "Current weather")
         return nil
      }
   }

   // MARK: - Daily

   func dailyForecast(for location: CLLocation) async -> [RideWeatherDay] {
      let key = Self.cacheKey(for: location.coordinate)

      if let cached = dailyCache[key], cached.expires > .now { return cached.days }
      if let existing = dailyInFlight[key] { return await existing.value }

      let task = Task { await fetchDaily(for: location, cacheKey: key) }
      dailyInFlight[key] = task
      let days = await task.value
      dailyInFlight[key] = nil

      return days
   }

   private func fetchDaily(for location: CLLocation, cacheKey: String) async -> [RideWeatherDay] {
      do {
         let forecast = try await weatherService.weather(for: location, including: .daily)
         let calendar = Calendar.current

         let days = forecast.forecast.map { day in
            RideWeatherDay(
               calendarDayStart: calendar.startOfDay(for: day.date),
               conditionSymbolName: day.symbolName,
               conditionLabel: day.condition.description,
               highCelsius: day.highTemperature.converted(to: .celsius).value,
               lowCelsius: day.lowTemperature.converted(to: .celsius).value,
               precipitationChance: day.precipitationChance,
               sunrise: day.sun.sunrise,
               sunset: day.sun.sunset,
               uvIndex: day.uvIndex.value
            )
         }

         availability = .ready
         dailyCache[cacheKey] = (days, Date.now.addingTimeInterval(dailyTTL))
         await refreshAttribution()
         return days
      } catch {
         record(error, stage: "Daily forecast")
         return []
      }
   }

   // MARK: - Precipitation

   func precipOutlook(for location: CLLocation) async -> RidePrecipOutlook {
      let key = Self.cacheKey(for: location.coordinate)

      if let cached = outlookCache[key], cached.expires > .now { return cached.outlook }
      if let existing = outlookInFlight[key] { return await existing.value }

      let task = Task { await fetchOutlook(for: location, cacheKey: key) }
      outlookInFlight[key] = task
      let outlook = await task.value
      outlookInFlight[key] = nil

      return outlook
   }

   private func fetchOutlook(
      for location: CLLocation,
      cacheKey: String
   ) async -> RidePrecipOutlook {
      do {
         let (hourly, minute) = try await weatherService.weather(
            for: location,
            including: .hourly, .minute
         )

         let hours = hourly.forecast.map { hour in
            RideWeatherHour(
               date: hour.date,
               conditionSymbolName: hour.symbolName,
               conditionLabel: hour.condition.description,
               temperatureCelsius: hour.temperature.converted(to: .celsius).value,
               precipitationChance: hour.precipitationChance,
               precipitationAmountMillimeters: hour.precipitationAmount
                  .converted(to: .millimeters).value,
               snowfallAmountMillimeters: hour.snowfallAmount.converted(to: .millimeters).value
            )
         }

         // Apple publishes a minute forecast only in some regions; absent is
         // normal, not a failure. Intensity is normalised here so the chart
         // never has to reason about mm/hr.
         let minutes = (minute?.forecast ?? []).map { entry in
            RideWeatherMinute(
               date: entry.date,
               precipitationChance: entry.precipitationChance,
               precipitationIntensity: entry.precipitation == .none
                  ? 0
                  : max(entry.precipitationChance, 0.4)
            )
         }

         let outlook = RidePrecipOutlook(hours: hours, minutes: minutes)
         availability = .ready
         outlookCache[cacheKey] = (outlook, Date.now.addingTimeInterval(outlookTTL))
         await refreshAttribution()
         return outlook
      } catch {
         record(error, stage: "Precipitation outlook")
         return .empty
      }
   }

   // MARK: - Attribution

   /// Apple's terms require the legal link alongside any WeatherKit data, so it
   /// is refreshed with every successful fetch rather than assumed.
   private func refreshAttribution() async {
      guard attributionLegalURL == nil else { return }

      do {
         attributionLegalURL = try await weatherService.attribution.legalPageURL
      } catch {
         let failure = error as NSError
         DebugPrint(
            mode: .weather,
            "Attribution failed | domain=\(failure.domain) code=\(failure.code)"
         )
      }
   }

   // MARK: - Keys

   /// Two decimal places is roughly a kilometre — close enough that a rider
   /// crossing it is under the same sky, coarse enough that a moving GPS does
   /// not thrash the cache.
   private static func cacheKey(for coordinate: CLLocationCoordinate2D) -> String {
      String(
         format: "%.2f,%.2f",
         (coordinate.latitude * 100).rounded() / 100,
         (coordinate.longitude * 100).rounded() / 100
      )
   }

   // MARK: - Failure

   /// The one place a failed fetch is classified and logged, so all three call
   /// sites tell the rider and the console the same story.
   ///
   /// The raw domain and code are logged verbatim because WeatherKit's
   /// `localizedDescription` is frequently just "(null)", and the domain is the
   /// only part that distinguishes a signing problem from a tunnel.
   private func record(_ error: Error, stage: String) {
      availability = Self.classify(error)

      let failure = error as NSError
      DebugPrint(
         mode: .weather,
         """
         \(stage) failed → \(availability.rawValue) | \
         domain=\(failure.domain) code=\(failure.code) | \
         description=\(error.localizedDescription) | \
         userInfo=\(failure.userInfo.isEmpty ? "empty" : String(describing: failure.userInfo))
         """
      )
   }

   /// WeatherKit reports a missing entitlement, a dead network and a throttled
   /// account as three near-identical opaque daemon errors, so the mapping is
   /// deliberate rather than a keyword sweep over the whole message: a rider in
   /// a tunnel must never be told the build is broken.
   private static func classify(_ error: Error) -> RideWeatherAvailability {
      if let weatherError = error as? WeatherError {
         switch weatherError {
            case .permissionDenied: return .notEntitled
            default: return .unavailable
         }
      }

      let failure = error as NSError

      if offlineDomains.contains(failure.domain) { return .offline }

      // The JWT handshake runs before any weather request leaves the device, so
      // an authenticator failure is always the signature, the App ID or the
      // WeatherKit App Service — never the sky and never the connection.
      if failure.domain.contains("JWTAuthenticator") { return .notEntitled }

      let text = "\(failure.domain) \(failure.code) \(error.localizedDescription)".lowercased()

      if failure.code == 429 || text.contains("rate limit") || text.contains("too many requests") {
         return .rateLimited
      }

      if text.contains("not entitled")
         || text.contains("entitlement")
         || text.contains("unauthorized")
         || text.contains("forbidden") {
         return .notEntitled
      }

      if text.contains("offline") || text.contains("internet connection") { return .offline }

      return .unavailable
   }

   private static let offlineDomains: Set<String> = [
      NSURLErrorDomain,
      kCFErrorDomainCFNetwork as String
   ]
}

// MARK: - Facade

/// The view layer's door to WeatherKit, awaiting the off-main client.
///
/// Exists so no view model has to know the client is an actor, and so
/// availability and the attribution URL are observable in one place.
@Observable
@MainActor
final class RideWeatherService {

   private(set) var availability: RideWeatherAvailability = .unknown
   private(set) var attributionLegalURL: URL?

   @ObservationIgnored private let client = RideWeatherClient.shared

   func currentWeather(for location: CLLocation) async -> RideWeatherSnapshot? {
      let snapshot = await client.currentWeather(for: location)
      await syncMetadata()
      return snapshot
   }

   func dailyForecast(for location: CLLocation) async -> [RideWeatherDay] {
      let days = await client.dailyForecast(for: location)
      await syncMetadata()
      return days
   }

   func precipOutlook(for location: CLLocation) async -> RidePrecipOutlook {
      let outlook = await client.precipOutlook(for: location)
      await syncMetadata()
      return outlook
   }

   private func syncMetadata() async {
      availability = await client.currentAvailability()
      attributionLegalURL = await client.currentAttributionURL()
   }
}
