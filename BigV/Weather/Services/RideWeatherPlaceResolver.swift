//
//  RideWeatherPlaceResolver.swift
//  BigV
//

import CoreLocation
import Foundation
import MapKit

/// Turns a coordinate into the town name a rider would recognise.
///
/// A weather card headed "37.23, −122.02" is useless, and the GPS only ever
/// hands over numbers. Failure is expected and cheap — the caller falls back to
/// a generic label rather than blocking on a name.
nonisolated enum RideWeatherPlaceResolver {

   static func localityLabel(for location: CLLocation) async -> String? {
      guard let request = MKReverseGeocodingRequest(location: location),
            let mapItem = try? await request.mapItems.first
      else { return nil }

      if let city = trimmed(mapItem.addressRepresentations?.cityName) { return city }
      if let context = trimmed(mapItem.addressRepresentations?.cityWithContext) { return context }

      return trimmed(mapItem.name)
   }

   private static func trimmed(_ value: String?) -> String? {
      guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
      else { return nil }

      return value
   }
}
