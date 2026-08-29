//
//  RideWeatherPlaceStore.swift
//  BigV
//

import CoreLocation
import Foundation

/// Remembers a city the rider pinned in the weather sheet.
///
/// Separate from `RideUnitsSettings` because this is a place, not a preference:
/// it is written by a search result and cleared by a tap on the GPS, and
/// nothing outside the weather feature reads it.
nonisolated enum RideWeatherPlaceStore {

   // MARK: - Keys

   private enum Key {
      static let latitude = "ride.weather.pin.latitude"
      static let longitude = "ride.weather.pin.longitude"
      static let label = "ride.weather.pin.label"
   }

   // MARK: - Access

   static func pinnedPlace(in defaults: UserDefaults = .standard) -> RideWeatherPlace? {
      guard defaults.object(forKey: Key.latitude) != nil,
            defaults.object(forKey: Key.longitude) != nil
      else { return nil }

      let coordinate = CLLocationCoordinate2D(
         latitude: defaults.double(forKey: Key.latitude),
         longitude: defaults.double(forKey: Key.longitude)
      )
      guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }

      let label = defaults.string(forKey: Key.label) ?? ""
      return .pinned(coordinate: coordinate, label: label.isEmpty ? "Pinned" : label)
   }

   static func save(_ place: RideWeatherPlace, in defaults: UserDefaults = .standard) {
      defaults.set(place.latitude, forKey: Key.latitude)
      defaults.set(place.longitude, forKey: Key.longitude)
      defaults.set(place.label, forKey: Key.label)
   }

   static func clear(in defaults: UserDefaults = .standard) {
      defaults.removeObject(forKey: Key.latitude)
      defaults.removeObject(forKey: Key.longitude)
      defaults.removeObject(forKey: Key.label)
   }
}
