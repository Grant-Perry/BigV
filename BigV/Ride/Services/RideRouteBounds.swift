//
//  RideRouteBounds.swift
//  BigV
//

import CoreLocation
import Foundation
import MapKit

/// Frames a finished route in a map camera.
///
/// Pure geometry, so the fitting rule can be tested without a map.
///
/// - Note: A route that crosses the antimeridian would fit to the wrong half of
///   the world. Not handled: a single bicycle ride spanning 180° of longitude is
///   not a case worth carrying complexity for.
enum RideRouteBounds {

   // MARK: - Tuning

   /// Smallest span the camera will use, in degrees. Roughly 250 m, so a single
   /// point or a lap of a car park still shows recognisable surroundings instead
   /// of a texture-less zoom.
   static let minimumSpan: Double = 0.0025

   /// Breathing room around the track so the line never touches the frame edge.
   static let paddingFactor: Double = 1.35

   private static let maximumLatitudeSpan: Double = 170
   private static let maximumLongitudeSpan: Double = 350

   // MARK: - Fitting

   /// The region that frames `coordinates`, or `nil` when there is nothing to frame.
   static func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
      guard let first = coordinates.first else { return nil }

      var minimumLatitude = first.latitude
      var maximumLatitude = first.latitude
      var minimumLongitude = first.longitude
      var maximumLongitude = first.longitude

      for coordinate in coordinates.dropFirst() {
         minimumLatitude = min(minimumLatitude, coordinate.latitude)
         maximumLatitude = max(maximumLatitude, coordinate.latitude)
         minimumLongitude = min(minimumLongitude, coordinate.longitude)
         maximumLongitude = max(maximumLongitude, coordinate.longitude)
      }

      let center = CLLocationCoordinate2D(
         latitude: (minimumLatitude + maximumLatitude) / 2,
         longitude: (minimumLongitude + maximumLongitude) / 2
      )

      let span = MKCoordinateSpan(
         latitudeDelta: clamped(
            (maximumLatitude - minimumLatitude) * paddingFactor,
            ceiling: maximumLatitudeSpan
         ),
         longitudeDelta: clamped(
            (maximumLongitude - minimumLongitude) * paddingFactor,
            ceiling: maximumLongitudeSpan
         )
      )

      return MKCoordinateRegion(center: center, span: span)
   }

   // MARK: - Clamping

   private static func clamped(_ delta: Double, ceiling: Double) -> Double {
      guard delta.isFinite else { return minimumSpan }
      return min(max(delta, minimumSpan), ceiling)
   }
}
