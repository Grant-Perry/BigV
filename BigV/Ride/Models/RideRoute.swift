//
//  RideRoute.swift
//  BigV
//

import CoreLocation
import Foundation
import MapKit

/// A route that is ready to draw: display-thinned coordinates and the camera
/// region that frames them.
///
/// Both are resolved once, when the route is built, so no view ever recomputes
/// geometry while scrolling or redrawing.
struct RideRoute {

   // MARK: - Contents

   let coordinates: [CLLocationCoordinate2D]
   let region: MKCoordinateRegion?

   /// Two points are the minimum that can make a line. One sample, or none, is a
   /// ride with no route rather than a route to draw badly.
   var isDrawable: Bool { coordinates.count > 1 && region != nil }

   var startCoordinate: CLLocationCoordinate2D? { coordinates.first }
   var endCoordinate: CLLocationCoordinate2D? { coordinates.last }

   // MARK: - Initialization

   init(coordinates: [CLLocationCoordinate2D]) {
      self.coordinates = coordinates
      self.region = RideRouteBounds.region(for: coordinates)
   }

   static let empty = RideRoute(coordinates: [])
}

// MARK: - Equatable

/// Two routes are the same route when they draw the same points. Lets a map
/// re-frame exactly when its track changes and sit still when the same ride
/// is merely reloaded.
extension RideRoute: Equatable {

   static func == (lhs: RideRoute, rhs: RideRoute) -> Bool {
      guard lhs.coordinates.count == rhs.coordinates.count else { return false }
      return zip(lhs.coordinates, rhs.coordinates).allSatisfy {
         $0.latitude == $1.latitude && $0.longitude == $1.longitude
      }
   }
}
