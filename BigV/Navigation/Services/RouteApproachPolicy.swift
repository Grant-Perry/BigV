//
//  RouteApproachPolicy.swift
//  BigV
//

import CoreLocation
import Foundation

/// Decides whether the rider is already at a route's start, or needs a
/// lead-in from where they are standing.
///
/// Following a trail that begins a town away would start every ride off-route.
/// This is the one number that question hangs on.
nonisolated enum RouteApproachPolicy {

   /// Far enough from the first point that riding the line would begin off
   /// the route. Past a parking lot and typical GPS slop; short of "I can
   /// see the trailhead."
   static let nearStartDistance: CLLocationDistance = 200

   /// Whether Apple should be asked for cycling directions to `start`.
   static func needsApproach(
      from origin: CLLocationCoordinate2D,
      to start: CLLocationCoordinate2D
   ) -> Bool {
      guard RideRouteDownsampler.isUsable(origin),
            RideRouteDownsampler.isUsable(start)
      else { return false }

      return RideRouteDownsampler.meters(from: origin, to: start) > nearStartDistance
   }
}
