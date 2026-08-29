//
//  RideWeatherPlace.swift
//  BigV
//

import CoreLocation
import Foundation

/// Where the weather is being read, and why.
///
/// The source matters to the UI, not just to the fetch: a rider who pinned a
/// city gets a way back to the GPS, and one already on the GPS must not be
/// offered it.
nonisolated struct RideWeatherPlace: Identifiable, Hashable, Sendable {

   enum Source: Hashable, Sendable {
      /// Wherever the rider is standing.
      case device
      /// A city the rider searched for and kept.
      case pinned
   }

   let id: UUID
   let latitude: Double
   let longitude: Double
   let label: String
   let source: Source

   init(
      id: UUID = UUID(),
      coordinate: CLLocationCoordinate2D,
      label: String,
      source: Source
   ) {
      self.id = id
      self.latitude = coordinate.latitude
      self.longitude = coordinate.longitude
      self.label = label
      self.source = source
   }

   // MARK: - Geometry

   var coordinate: CLLocationCoordinate2D {
      CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
   }

   var location: CLLocation {
      CLLocation(latitude: latitude, longitude: longitude)
   }

   var isFollowingDevice: Bool { source == .device }

   // MARK: - Factories

   static func device(coordinate: CLLocationCoordinate2D, label: String) -> RideWeatherPlace {
      RideWeatherPlace(coordinate: coordinate, label: label, source: .device)
   }

   static func pinned(coordinate: CLLocationCoordinate2D, label: String) -> RideWeatherPlace {
      RideWeatherPlace(coordinate: coordinate, label: label, source: .pinned)
   }
}
