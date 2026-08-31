//
//  RideRetraceRouteBuilder.swift
//  BigV
//

import CoreLocation
import Foundation

/// Turns the ride's recorded breadcrumb into the route home.
///
/// The reversal is the feature: the rider came this way, so the way back is
/// the same line ridden backwards. No provider, no network — which is exactly
/// why it works where MapKit has no cycling coverage. Kept pure so the
/// reversal rule is testable with plain coordinates.
enum RideRetraceRouteBuilder {

   /// The breadcrumb reversed into a rideable `PlannedRoute`, or `nil` when
   /// the ride has too little track to lead anywhere.
   ///
   /// Distance is left to the factory's own geometry measurement, and travel
   /// time is unknowable without a provider — zero reads as "no estimate"
   /// everywhere downstream.
   static func route(
      reversing breadcrumb: [CLLocationCoordinate2D],
      id: UUID = UUID()
   ) -> PlannedRoute? {
      guard breadcrumb.count > 1 else { return nil }

      let draft = PlannedRouteFactory.Draft(
         name: "Back to Start",
         coordinates: breadcrumb.reversed(),
         distance: 0,
         expectedTravelTime: 0
      )

      return PlannedRouteFactory.route(from: draft, source: .retrace, id: id)
   }
}
