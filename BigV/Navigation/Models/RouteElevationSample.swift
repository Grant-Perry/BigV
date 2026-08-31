//
//  RouteElevationSample.swift
//  BigV
//

import CoreLocation
import Foundation

/// One point of a planned route's elevation profile.
///
/// `distanceAlongRoute` is in the same provider-scaled space as
/// `RouteGuidanceProgress.distanceAlongRoute`, which is what lets remaining
/// climb be an integral from that scalar rather than a geometry search. Kept
/// deliberately tiny — a profile carries hundreds of these.
nonisolated struct RouteElevationSample: Sendable, Equatable {

   /// Meters from the route start.
   let distanceAlongRoute: CLLocationDistance

   /// Meters above sea level.
   let altitude: Double
}
