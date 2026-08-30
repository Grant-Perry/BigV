//
//  RideWeatherStamper.swift
//  BigV
//

import CoreLocation
import Foundation

/// Stamps WeatherKit conditions onto the ride being recorded.
///
/// Lives between the session manager and storage so neither has to know
/// WeatherKit exists: the session says *when* (first fix, finalize), the
/// client says *what*, and storage says *where it lands*. Every failure is
/// silent by design — a ride with no sky recorded is a complete ride.
@MainActor
struct RideWeatherStamper {

   // MARK: - Dependencies

   private let rideStorageManager: RideStorageManager

   // MARK: - Initialization

   init(rideStorageManager: RideStorageManager) {
      self.rideStorageManager = rideStorageManager
   }

   // MARK: - Stamping

   /// Fetches conditions at the first GPS fix and writes them to the active
   /// ride. The client caches by coordinate, so this costs one WeatherKit
   /// round trip that the live weather chip was probably about to spend anyway.
   func stampStart(latitude: Double, longitude: Double) async {
      let location = CLLocation(latitude: latitude, longitude: longitude)

      guard let snapshot = await RideWeatherClient.shared.currentWeather(for: location) else {
         DebugPrint(mode: .weather, "Start weather unavailable; ride records without a sky")
         return
      }

      rideStorageManager.applyStartWeather(snapshot)
   }

   /// Fetches conditions where the ride ended and stamps the closing
   /// temperature onto the already-finalized row.
   func stampEnd(on ride: Ride, latitude: Double?, longitude: Double?) async {
      guard let latitude, let longitude else { return }
      let location = CLLocation(latitude: latitude, longitude: longitude)

      guard let snapshot = await RideWeatherClient.shared.currentWeather(for: location) else {
         DebugPrint(mode: .weather, "End weather unavailable; ride keeps its start conditions")
         return
      }

      rideStorageManager.applyEndWeather(snapshot, to: ride)
   }
}
