//
//  RouteGuidanceProgress.swift
//  BigV
//

import CoreLocation
import Foundation

/// Where the rider is along the route they are following.
///
/// Kept out of `RideState` on purpose: that struct is equality-checked and
/// republished on every accepted GPS sample, and guidance is a separate concern
/// with a separate lifetime. This one is published by the guidance session and
/// observed only by the guidance UI.
///
/// Instructions are carried as strings rather than as `PlannedRouteManeuver`
/// values so the whole snapshot can be `Equatable` — `CLLocationCoordinate2D` is
/// not, and a maneuver holds one.
struct RouteGuidanceProgress: Sendable, Equatable {

   // MARK: - Tracking

   /// Whether the engine has located the rider on the route at all. False on the
   /// first samples of a route and while a degenerate route is loaded.
   var isTracking = false

   // MARK: - Along The Route (meters)

   var distanceAlongRoute: CLLocationDistance = 0
   var distanceRemaining: CLLocationDistance = 0

   /// How far the rider is from the drawn line, perpendicular to it.
   var lateralDeviation: CLLocationDistance = 0

   // MARK: - Time

   var estimatedTimeRemaining: TimeInterval = 0

   // MARK: - Instructions

   var upcomingManeuverID: PlannedRouteManeuver.ID?
   var upcomingInstruction: String?
   var upcomingNotice: String?
   var distanceToUpcomingManeuver: CLLocationDistance?

   /// The instruction after the upcoming one, for the "then" line. A rider
   /// approaching two turns in quick succession needs both at once.
   var followingInstruction: String?

   // MARK: - Exceptions

   var isOffRoute = false

   /// The rider is retracing the route rather than following it. Worth saying out
   /// loud, because every instruction ahead of them is behind them.
   var isAgainstRoute = false

   var hasArrived = false

   // MARK: - Presets

   static let inactive = RouteGuidanceProgress()
}
