//
//  ClimbProgress.swift
//  BigV
//

import CoreLocation
import Foundation

/// Where the rider stands against the climbs ahead of them.
///
/// Published by `RideClimbModel` and read by the climb page and the dashboard
/// tile. Kept out of `RideState` for the same reason guidance progress is:
/// that struct is equality-checked on every accepted GPS sample, and climbs
/// are a separate concern with a separate lifetime.
///
/// Every forward-looking field is optional and `nil` means "not known", never
/// zero: a route without an elevation profile, or no route at all, must show
/// nothing rather than a confident wrong number.
struct ClimbProgress: Sendable, Equatable {

   // MARK: - Route

   /// Whether the active route carries an elevation profile at all. False on
   /// freeride and on a route Open-Meteo could not enrich; every remaining
   /// figure below is `nil` when this is false.
   var hasRouteProfile = false

   /// Meters of ascent left between here and the route's end.
   var routeAscentRemaining: Double?

   // MARK: - This Climb

   /// The climb the rider is currently on, when there is one.
   var activeClimb: PlannedClimb?

   /// Meters of road left to this climb's top.
   var distanceToTop: CLLocationDistance?

   /// Meters of ascent left on this climb.
   var climbAscentRemaining: Double?

   /// Average grade of what is left of this climb, as a percentage.
   var averageRemainingGrade: Double?

   // MARK: - Playhead

   /// The rider's position in route distance, for the profile playhead.
   var playheadDistance: CLLocationDistance?

   /// The profile's altitude at the playhead, interpolated.
   var playheadAltitude: Double?

   // MARK: - Next Climb

   /// The next climb up the road, when the rider is between climbs.
   var nextClimb: PlannedClimb?

   /// Meters of road to the next climb's base.
   var distanceToNextClimb: CLLocationDistance?

   // MARK: - Presets

   static let none = ClimbProgress()
}
