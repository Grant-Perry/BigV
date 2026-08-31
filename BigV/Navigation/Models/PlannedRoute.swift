//
//  PlannedRoute.swift
//  BigV
//

import CoreLocation
import Foundation

/// A route the rider intends to follow, independent of who produced it.
///
/// Distinct from `RideRoute`, which is the breadcrumb of where the rider has
/// already been. This is the other direction: where they are going.
///
/// Deliberately free of MapKit. Everything here can be filled from an Apple
/// directions response, a GPX file or a trail API, so guidance consumes one shape
/// and never learns which provider is behind it. Distances are meters and times
/// are seconds, matching `RideState`.
nonisolated struct PlannedRoute: Identifiable, Sendable {

   // MARK: - Identity

   let id: UUID

   let source: PlannedRouteSource

   /// The provider's own label for the route, such as a street it mostly
   /// follows. Empty when the provider offers nothing.
   let name: String

   // MARK: - Geometry

   let coordinates: [CLLocationCoordinate2D]

   /// Total route length in meters.
   let distance: CLLocationDistance

   /// The provider's estimate in seconds. Apple's cycling estimate is not
   /// traffic-aware; no provider gives a live one for a bicycle.
   let expectedTravelTime: TimeInterval

   // MARK: - Instructions

   let maneuvers: [PlannedRouteManeuver]

   /// Provider-supplied route conditions, already localized.
   let advisories: [String]

   // MARK: - Elevation

   /// Altitude along the route, in the provider's distance space. Empty until
   /// a GPX file supplies altitudes or Open-Meteo enrichment lands; a route is
   /// fully rideable without it, the climb surfaces just stay hidden.
   var elevationProfile: [RouteElevationSample] = []

   /// The climbs `ClimbDetector` found in the profile, in route order.
   var climbs: [PlannedClimb] = []

   // MARK: - Derived

   /// Two points are the minimum that can make a line.
   var isDrawable: Bool { coordinates.count > 1 }

   var startCoordinate: CLLocationCoordinate2D? { coordinates.first }
   var endCoordinate: CLLocationCoordinate2D? { coordinates.last }

   var hasAdvisories: Bool { !advisories.isEmpty }

   /// Two samples are the minimum that can make a slope.
   var hasElevationProfile: Bool { elevationProfile.count > 1 }

   /// Total meters of ascent over the whole route. `nil` without a profile, so
   /// no view can mistake "unknown" for "flat".
   var totalAscent: Double? {
      guard hasElevationProfile else { return nil }
      return zip(elevationProfile, elevationProfile.dropFirst()).reduce(0) {
         $0 + max(0, $1.1.altitude - $1.0.altitude)
      }
   }
}
