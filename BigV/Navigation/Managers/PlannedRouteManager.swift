//
//  PlannedRouteManager.swift
//  BigV
//

import CoreLocation
import Foundation

/// Owns the one route the rider has committed to following.
///
/// Kept out of `RideState` for the same reason the breadcrumb is: that struct is
/// equality-checked and republished on every accepted GPS sample, and a route
/// carrying thousands of coordinates would make every one of those checks more
/// expensive. Only the map and the planner observe this.
///
/// A route outlives a ride on purpose. A rider can plan while idle, start
/// recording, finish, and still be following the same line home.
///
/// - Note: This is where stage two attaches. A guidance engine takes
///   `activeRoute` plus the location stream and publishes its own progress
///   state — next maneuver, distance to it, off-route — without this type or
///   anything below it changing.
@Observable
@MainActor
final class PlannedRouteManager {

   // MARK: - Published State

   private(set) var activeRoute: PlannedRoute?

   /// Where the active route is headed, kept alongside it so the map can label
   /// the endpoint with the name the rider searched for rather than a coordinate.
   private(set) var destination: RouteDestination?

   var hasActiveRoute: Bool { activeRoute?.isDrawable ?? false }

   // MARK: - Intent

   func activate(_ route: PlannedRoute, to destination: RouteDestination) {
      activeRoute = route
      self.destination = destination

      DebugPrint(
         mode: .navigation,
         "Activated \(route.source.rawValue) route to \(destination.name): \(route.coordinates.count) points, \(route.maneuvers.count) maneuvers"
      )
   }

   /// Attaches elevation to the active route in place, if it is still the one
   /// the enrichment was fetched for.
   ///
   /// Deliberately not a re-activation: guidance keys on the route's identity
   /// and re-preparing the engine mid-ride would restart every cue latch. The
   /// geometry does not change here — only the profile riding alongside it.
   func attachElevation(from enriched: PlannedRoute) {
      guard var route = activeRoute, route.id == enriched.id else { return }

      route.elevationProfile = enriched.elevationProfile
      route.climbs = enriched.climbs
      activeRoute = route

      DebugPrint(
         mode: .navigation,
         "Attached elevation to active route: \(enriched.elevationProfile.count) samples, \(enriched.climbs.count) climb(s)"
      )
   }

   func clear() {
      guard activeRoute != nil else { return }

      activeRoute = nil
      destination = nil

      DebugPrint(mode: .navigation, "Cleared planned route")
   }
}
