//
//  RouteGuidanceEvent.swift
//  BigV
//

import CoreLocation
import Foundation

/// A turn worth calling out, and how close the rider is to it.
struct RouteGuidanceCue: Sendable, Equatable {

   let maneuverID: PlannedRouteManeuver.ID
   let band: RouteGuidanceCueBand
   let instruction: String

   /// Meters to the maneuver when the band was crossed.
   let distance: CLLocationDistance
}

/// Something the guidance engine decided, for whoever owns the consequences.
///
/// The engine speaks nothing and reroutes nothing. It reports, and the session
/// owner turns a report into a spoken phrase, a haptic or a routing request —
/// which is what keeps the engine pure enough to test synchronously.
enum RouteGuidanceEvent: Sendable, Equatable {

   case cue(RouteGuidanceCue)

   /// Deviation from the route has been sustained long enough to be real.
   case departedRoute

   /// The rider is back on the line and tracking has resumed.
   case regainedRoute

   case arrived
}
