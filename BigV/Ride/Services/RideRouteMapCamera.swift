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

   /// A frame for a map whose top and bottom are covered by chrome.
   ///
   /// Stretches the span so the route fits the uncovered strip, then moves the
   /// centre so that strip — not the full map — sits over the route. Falls
   /// back to the plain frame when the covers leave nothing to draw in.
   static func position(
      highlight: RideRouteMapHighlight?,
      route: RideRoute,
      framedIn height: CGFloat,
      coveredTop: CGFloat,
      coveredBottom: CGFloat
   ) -> MapCameraPosition {
      guard var region = region(highlight: highlight, route: route) else {
         return .automatic
      }

      let visible = height - coveredTop - coveredBottom
      guard height > 0, visible > 40 else { return .region(region) }

      let stretch = height / visible
      region.span.latitudeDelta *= stretch
      region.span.longitudeDelta *= stretch

      // Degrees of latitude per point, then the shift that puts the strip's
      // middle where the map's middle used to be.
      let degreesPerPoint = region.span.latitudeDelta / height
      let shiftPoints = (coveredBottom - coveredTop) / 2
      region.center.latitude -= Double(shiftPoints) * degreesPerPoint

      return .region(region)
   }
}
