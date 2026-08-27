//
//  PlannedRouteProviding.swift
//  BigV
//

import CoreLocation
import Foundation

/// Anything that can produce candidate routes between two points.
///
/// The seam that keeps the app off MapKit. A GPX importer or a trail API becomes
/// another conformance; the view models, the map and stage two's guidance never
/// change because they only ever see `PlannedRoute`.
@MainActor
protocol PlannedRouteProviding {

   /// Candidates ordered as the provider ranked them, best first. Never empty:
   /// a provider with nothing to offer throws instead, so the caller cannot
   /// mistake "no bike route exists" for "here are zero routes".
   func routes(
      from origin: CLLocationCoordinate2D,
      to destination: RouteDestination
   ) async throws(RoutePlanningFailure) -> [PlannedRoute]

   /// Abandons any request in flight.
   func cancel()
}
