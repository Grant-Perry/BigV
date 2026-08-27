//
//  PlannedRouteManeuver.swift
//  BigV
//

import CoreLocation
import Foundation

/// One instruction along a planned route.
///
/// `distanceFromStart` is what makes this useful to guidance: once the rider's
/// progress along the route is known as a single scalar, the next maneuver and
/// the distance to it are a subtraction rather than a geometry search. Step
/// geometry is deliberately not duplicated here — the route already holds it.
struct PlannedRouteManeuver: Identifiable, Sendable {

   // MARK: - Identity

   /// Position in the route's maneuver list. Stable for the life of the route,
   /// which is all guidance needs to remember where it got to.
   let id: Int

   // MARK: - Instruction

   let instruction: String

   /// A legal or safety notice attached to this step, such as a level crossing
   /// warning. Rare, and worth showing verbatim when present.
   let notice: String?

   // MARK: - Geometry

   /// Length of this step in meters.
   let distance: CLLocationDistance

   /// Meters from the route start to the point this instruction applies to.
   let distanceFromStart: CLLocationDistance

   /// Where the instruction applies.
   let coordinate: CLLocationCoordinate2D
}
