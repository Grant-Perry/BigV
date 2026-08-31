//
//  PlannedRouteApproachAssembler.swift
//  BigV
//

import CoreLocation
import Foundation

/// Stitches a cycling lead-in in front of the course the rider meant to ride.
///
/// One `PlannedRoute` so guidance, the map and the ETA all see a single line:
/// turn-by-turn to the trailhead, then the trail. The course's source and name
/// survive, because that is still the ride they asked for.
nonisolated enum PlannedRouteApproachAssembler {

   /// Close enough that the approach already ends on the course's first point.
   private static let joinTolerance: CLLocationDistance = 8

   /// Approach plus course, or `nil` when either side is not drawable.
   static func stitched(approach: PlannedRoute, course: PlannedRoute) -> PlannedRoute? {
      guard approach.isDrawable, course.isDrawable else { return nil }

      let joinDistance = measuredDistance(of: approach)
      let courseDistance = measuredDistance(of: course)
      let coordinates = joinedCoordinates(approach: approach.coordinates, course: course.coordinates)
      guard coordinates.count > 1 else { return nil }

      let profile = combinedProfile(approach: approach, course: course, join: joinDistance)

      return PlannedRoute(
         id: UUID(),
         source: course.source,
         name: course.name,
         coordinates: coordinates,
         distance: joinDistance + courseDistance,
         expectedTravelTime: approach.expectedTravelTime + course.expectedTravelTime,
         maneuvers: joinedManeuvers(approach: approach, course: course, join: joinDistance),
         advisories: approach.advisories + course.advisories,
         elevationProfile: profile,
         climbs: ClimbDetector.climbs(in: profile),
         approachDistance: joinDistance
      )
   }

   // MARK: - Geometry

   private static func joinedCoordinates(
      approach: [CLLocationCoordinate2D],
      course: [CLLocationCoordinate2D]
   ) -> [CLLocationCoordinate2D] {
      guard let approachEnd = approach.last, let courseStart = course.first else {
         return approach + course
      }

      let gap = RideRouteDownsampler.meters(from: approachEnd, to: courseStart)
      if gap < joinTolerance {
         return approach + course.dropFirst()
      }

      return approach + course
   }

   // MARK: - Maneuvers

   private static func joinedManeuvers(
      approach: PlannedRoute,
      course: PlannedRoute,
      join: CLLocationDistance
   ) -> [PlannedRouteManeuver] {
      var maneuvers: [PlannedRouteManeuver] = []
      maneuvers.reserveCapacity(approach.maneuvers.count + course.maneuvers.count + 1)

      for maneuver in approach.maneuvers {
         maneuvers.append(copy(maneuver, id: maneuvers.count, offset: 0))
      }

      if let start = course.startCoordinate {
         let label = course.name.isEmpty ? "the route" : course.name
         maneuvers.append(
            PlannedRouteManeuver(
               id: maneuvers.count,
               instruction: "Start of \(label)",
               notice: nil,
               distance: 0,
               distanceFromStart: join,
               coordinate: start
            )
         )
      }

      for maneuver in course.maneuvers {
         maneuvers.append(copy(maneuver, id: maneuvers.count, offset: join))
      }

      return maneuvers
   }

   private static func copy(
      _ maneuver: PlannedRouteManeuver,
      id: Int,
      offset: CLLocationDistance
   ) -> PlannedRouteManeuver {
      PlannedRouteManeuver(
         id: id,
         instruction: maneuver.instruction,
         notice: maneuver.notice,
         distance: maneuver.distance,
         distanceFromStart: maneuver.distanceFromStart + offset,
         coordinate: maneuver.coordinate
      )
   }

   // MARK: - Elevation

   /// Profiles only combine when both sides already have one. A missing half
   /// would put climbs on the wrong stretch, so the stitched route waits on
   /// enrichment like any other incomplete line.
   private static func combinedProfile(
      approach: PlannedRoute,
      course: PlannedRoute,
      join: CLLocationDistance
   ) -> [RouteElevationSample] {
      guard approach.hasElevationProfile, course.hasElevationProfile else { return [] }

      let tail = course.elevationProfile.map { sample in
         RouteElevationSample(
            distanceAlongRoute: sample.distanceAlongRoute + join,
            altitude: sample.altitude
         )
      }

      return approach.elevationProfile + tail
   }

   // MARK: - Distance

   /// Trusts a provider total when it has one; measures the line when a test
   /// fixture or a GPX import left the figure at zero.
   private static func measuredDistance(of route: PlannedRoute) -> CLLocationDistance {
      if route.distance.isFinite, route.distance > 1 { return route.distance }
      return length(of: route.coordinates)
   }

   private static func length(of coordinates: [CLLocationCoordinate2D]) -> CLLocationDistance {
      zip(coordinates, coordinates.dropFirst()).reduce(0) { total, pair in
         total + RideRouteDownsampler.meters(from: pair.0, to: pair.1)
      }
   }
}
