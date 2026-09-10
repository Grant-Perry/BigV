//
//  RideRouteMapCamera.swift
//  BigV
//

import MapKit
import SwiftUI

/// The region a saved-ride map should look at: the highlighted slice when
/// there is one, otherwise the whole ride.
enum RideRouteMapCamera {

   static func region(highlight: RideRouteMapHighlight?, route: RideRoute) -> MKCoordinateRegion? {
      highlight?.route.region ?? route.region
   }

   static func position(highlight: RideRouteMapHighlight?, route: RideRoute) -> MapCameraPosition {
      guard let region = region(highlight: highlight, route: route) else {
         return .automatic
      }
      return .region(region)
   }
}
