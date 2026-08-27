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
struct PlannedRoute: Identifiable, Sendable {

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

   // MARK: - Derived

   /// Two points are the minimum that can make a line.
   var isDrawable: Bool { coordinates.count > 1 }

   var startCoordinate: CLLocationCoordinate2D? { coordinates.first }
   var endCoordinate: CLLocationCoordinate2D? { coordinates.last }

   var hasAdvisories: Bool { !advisories.isEmpty }
}
