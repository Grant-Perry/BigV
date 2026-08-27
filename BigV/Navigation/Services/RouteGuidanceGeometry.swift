//
//  RouteGuidanceGeometry.swift
//  BigV
//

import CoreLocation
import Foundation

/// Projects a rider onto a route polyline.
///
/// The one hard problem in turn-by-turn guidance: reducing a position to a single
/// scalar "how far along am I" without ever snapping to the wrong part of the
/// line. A route that doubles back on itself puts two stretches of road within a
/// few meters of each other, and a naive nearest-point search will happily place
/// a rider on the wrong one — a kilometre ahead of, or behind, where they are.
///
/// Two rules stop that, both applied here rather than in the engine:
/// - **Ambiguity band.** Candidates within `ambiguityBand` of the closest one are
///   treated as equally close, because GPS cannot distinguish them.
/// - **Course agreement.** Among equally close candidates, only those whose
///   segment runs roughly the way the rider is facing are eligible. Outbound and
///   return legs of a doubled-back route differ by 180 degrees, so heading alone
///   separates them.
///
/// Pure math with no framework side effects, in the same spirit as
/// `RideTelemetryEngine`. Distances use the same equirectangular approximation as
/// `RideRouteDownsampler`: under a percent of error at these scales, and it
/// allocates nothing.
enum RouteGuidanceGeometry {

   // MARK: - Constants

   private static let earthRadius: Double = 6_371_000
   private static let degreesToRadians: Double = .pi / 180

   /// Candidates this close to the best one cannot be told apart by GPS, so the
   /// tie is broken by heading and continuity instead of by centimetres.
   static let ambiguityBand: CLLocationDistance = 20

   /// Lateral distances are compared in steps of this size rather than exactly.
   ///
   /// Two placements whose perpendicular distances differ by less than a couple of
   /// meters are the same answer, and only then is heading or continuity allowed
   /// to decide between them. Comparing exactly would let the nearest-by-a-
   /// centimetre candidate win; comparing loosely would let a clearly worse one
   /// win on continuity alone, which is how progress gets stuck and a rider
   /// retracing the route goes unnoticed.
   static let lateralComparisonStep: CLLocationDistance = 2

   /// How far a segment's bearing may differ from the rider's course and still
   /// count as the road they are on. Wide enough to survive a bend taken at
   /// speed, tight enough to reject the opposite carriageway.
   static let courseAgreementLimit: Double = 100

   // MARK: - Projection

   /// One candidate placement of the rider on the route.
   struct Projection: Sendable, Equatable {

      /// Meters from the route start, measured along the drawn geometry.
      let distanceAlongRoute: CLLocationDistance

      /// Meters from the rider to the line, perpendicular to it.
      let lateralDistance: CLLocationDistance

      let segmentIndex: Int

      /// Direction the segment runs, in degrees clockwise from north.
      let bearing: Double
   }

   // MARK: - Cumulative Distances

   /// Distance from the route start to each vertex. Same count as the input, so
   /// index `i` addresses vertex `i` and segment `i` spans `i...i + 1`.
   ///
   /// Computed once per route: it is what turns "where am I" from a scan of the
   /// whole polyline into a lookup plus a handful of segment tests.
   static func cumulativeDistances(
      for coordinates: [CLLocationCoordinate2D]
   ) -> [CLLocationDistance] {
      guard !coordinates.isEmpty else { return [] }

      var cumulative = [CLLocationDistance](repeating: 0, count: coordinates.count)

      for index in 1..<max(1, coordinates.count) {
         cumulative[index] = cumulative[index - 1]
            + RideRouteDownsampler.meters(from: coordinates[index - 1], to: coordinates[index])
      }

      return cumulative
   }

   // MARK: - Segment Windows

   /// Segment indices covering `lower...upper` meters along the route.
   ///
   /// A rider moves a few meters per sample, so guidance only ever needs the
   /// handful of segments around its last known progress. Binary search rather
   /// than a scan keeps that lookup independent of route length.
   static func segmentRange(
      from lower: CLLocationDistance,
      to upper: CLLocationDistance,
      cumulative: [CLLocationDistance]
   ) -> Range<Int> {
      let segmentCount = cumulative.count - 1
      guard segmentCount > 0 else { return 0..<0 }

      let first = min(max(0, lastIndex(atOrBefore: lower, in: cumulative)), segmentCount - 1)
      let last = min(max(first, firstIndex(atOrAfter: upper, in: cumulative)), segmentCount - 1)

      return first..<(last + 1)
   }

   /// Highest vertex index whose cumulative distance is at or before `value`.
   private static func lastIndex(
      atOrBefore value: CLLocationDistance,
      in cumulative: [CLLocationDistance]
   ) -> Int {
      var low = 0
      var high = cumulative.count - 1
      var result = 0

      while low <= high {
         let middle = (low + high) / 2
         if cumulative[middle] <= value {
            result = middle
            low = middle + 1
         } else {
            high = middle - 1
         }
      }

      return result
   }

   /// Lowest vertex index whose cumulative distance is at or after `value`.
   private static func firstIndex(
      atOrAfter value: CLLocationDistance,
      in cumulative: [CLLocationDistance]
   ) -> Int {
      var low = 0
      var high = cumulative.count - 1
      var result = cumulative.count - 1

      while low <= high {
         let middle = (low + high) / 2
         if cumulative[middle] >= value {
            result = middle
            high = middle - 1
         } else {
            low = middle + 1
         }
      }

      return result
   }

   // MARK: - Locating

   /// The best placement of `coordinate` on the segments in `range`.
   ///
   /// - Parameters:
   ///   - course: Rider heading in degrees, negative when unknown. Used only to
   ///     break ties between equally close candidates.
   ///   - anchor: Last known progress in meters. When present, ties resolve to
   ///     the candidate nearest it, which keeps tracking continuous through a
   ///     hairpin. When absent — the first sample, or after re-acquiring — ties
   ///     resolve to the *earliest* candidate, because a rider on a stretch the
   ///     route covers twice has not ridden it yet.
   static func locate(
      _ coordinate: CLLocationCoordinate2D,
      on coordinates: [CLLocationCoordinate2D],
      cumulative: [CLLocationDistance],
      in range: Range<Int>,
      course: Double,
      anchor: CLLocationDistance?
   ) -> Projection? {
      guard coordinates.count > 1, cumulative.count == coordinates.count, !range.isEmpty else {
         return nil
      }

      let bounded = range.clamped(to: 0..<(coordinates.count - 1))
      guard !bounded.isEmpty else { return nil }

      var closest: CLLocationDistance = .greatestFiniteMagnitude

      for index in bounded {
         guard let projection = project(coordinate, ontoSegmentAt: index, coordinates, cumulative)
         else { continue }
         closest = min(closest, projection.lateralDistance)
      }

      guard closest < .greatestFiniteMagnitude else { return nil }

      let ceiling = closest + ambiguityBand
      var bestAligned: Projection?
      var bestAny: Projection?

      for index in bounded {
         guard let projection = project(coordinate, ontoSegmentAt: index, coordinates, cumulative),
               projection.lateralDistance <= ceiling
         else { continue }

         if isBetter(projection, than: bestAny, anchor: anchor) {
            bestAny = projection
         }

         guard course >= 0, bearingDelta(course, projection.bearing) <= courseAgreementLimit else {
            continue
         }

         if isBetter(projection, than: bestAligned, anchor: anchor) {
            bestAligned = projection
         }
      }

      // Falling back to `bestAny` matters: a rider stopped at a light has no
      // meaningful course, and one riding the route backwards agrees with no
      // segment at all. Neither should lose tracking.
      return bestAligned ?? bestAny
   }

   private static func isBetter(
      _ candidate: Projection,
      than incumbent: Projection?,
      anchor: CLLocationDistance?
   ) -> Bool {
      guard let incumbent else { return true }
      return rank(candidate, anchor: anchor) < rank(incumbent, anchor: anchor)
   }

   /// Closeness first, then whichever tie-break applies. Quantising the lateral
   /// distance keeps this a total order, so the winner never depends on the order
   /// segments happened to be visited in.
   private static func rank(
      _ projection: Projection,
      anchor: CLLocationDistance?
   ) -> (Int, CLLocationDistance) {
      let step = Int((projection.lateralDistance / lateralComparisonStep).rounded(.down))

      guard let anchor else { return (step, projection.distanceAlongRoute) }

      return (step, abs(projection.distanceAlongRoute - anchor))
   }

   // MARK: - Segment Math

   private static func project(
      _ coordinate: CLLocationCoordinate2D,
      ontoSegmentAt index: Int,
      _ coordinates: [CLLocationCoordinate2D],
      _ cumulative: [CLLocationDistance]
   ) -> Projection? {
      guard index >= 0, index + 1 < coordinates.count else { return nil }

      let start = planar(coordinates[index], relativeTo: coordinate)
      let end = planar(coordinates[index + 1], relativeTo: coordinate)

      let run = (x: end.x - start.x, y: end.y - start.y)
      let lengthSquared = run.x * run.x + run.y * run.y

      // A zero-length segment still places the rider: duplicated vertices are
      // common in provider geometry and must not create a hole in the route.
      guard lengthSquared > 0 else {
         return Projection(
            distanceAlongRoute: cumulative[index],
            lateralDistance: (start.x * start.x + start.y * start.y).squareRoot(),
            segmentIndex: index,
            bearing: bearing(from: coordinates[index], to: coordinates[index + 1])
         )
      }

      // The rider sits at the planar origin, so `-start` is the vector from the
      // segment's start to them.
      let along = (-start.x * run.x + -start.y * run.y) / lengthSquared
      let fraction = min(max(along, 0), 1)

      let closest = (x: start.x + run.x * fraction, y: start.y + run.y * fraction)
      let lateral = (closest.x * closest.x + closest.y * closest.y).squareRoot()

      let segmentLength = cumulative[index + 1] - cumulative[index]

      return Projection(
         distanceAlongRoute: cumulative[index] + segmentLength * fraction,
         lateralDistance: lateral,
         segmentIndex: index,
         bearing: bearing(from: coordinates[index], to: coordinates[index + 1])
      )
   }

   /// Meters east and north of `origin`, so segment tests are plane geometry.
   private static func planar(
      _ coordinate: CLLocationCoordinate2D,
      relativeTo origin: CLLocationCoordinate2D
   ) -> (x: Double, y: Double) {
      let meanLatitude = (origin.latitude + coordinate.latitude) / 2 * degreesToRadians
      let northing = (coordinate.latitude - origin.latitude) * degreesToRadians * earthRadius
      let easting = (coordinate.longitude - origin.longitude)
         * degreesToRadians * cos(meanLatitude) * earthRadius

      return (easting, northing)
   }

   // MARK: - Bearings

   /// Degrees clockwise from north, in the same convention as `CLLocation.course`.
   static func bearing(
      from origin: CLLocationCoordinate2D,
      to destination: CLLocationCoordinate2D
   ) -> Double {
      let meanLatitude = (origin.latitude + destination.latitude) / 2 * degreesToRadians
      let northing = (destination.latitude - origin.latitude) * degreesToRadians
      let easting = (destination.longitude - origin.longitude) * degreesToRadians
         * cos(meanLatitude)

      guard northing != 0 || easting != 0 else { return 0 }

      let degrees = atan2(easting, northing) / degreesToRadians
      return degrees < 0 ? degrees + 360 : degrees
   }

   /// Smallest absolute angle between two bearings, 0 through 180.
   static func bearingDelta(_ first: Double, _ second: Double) -> Double {
      let difference = abs(first - second).truncatingRemainder(dividingBy: 360)
      return difference > 180 ? 360 - difference : difference
   }
}
