//
//  RouteGuidanceGeometryTests.swift
//  BigVTests
//

import CoreLocation
import Testing
@testable import BigV

@MainActor
struct RouteGuidanceGeometryTests {

   // MARK: - Fixtures

   private static let origin = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)

   /// A coordinate `east` and `north` meters from the fixture origin.
   private func point(east: Double, north: Double) -> CLLocationCoordinate2D {
      RouteGuidanceTestGeography.coordinate(east: east, north: north, from: Self.origin)
   }

   /// A straight line running east, one vertex every 20 meters.
   private func straightLine(length: Double, north: Double = 0) -> [CLLocationCoordinate2D] {
      stride(from: 0, through: length, by: 20).map { point(east: $0, north: north) }
   }

   // MARK: - Cumulative Distances

   @Test func cumulativeDistancesMatchTheLineLength() {
      let line = straightLine(length: 200)
      let cumulative = RouteGuidanceGeometry.cumulativeDistances(for: line)

      #expect(cumulative.count == line.count)
      #expect(cumulative.first == 0)
      #expect(abs((cumulative.last ?? 0) - 200) < 2)
   }

   @Test func cumulativeDistancesOfADegenerateLine() {
      #expect(RouteGuidanceGeometry.cumulativeDistances(for: []).isEmpty)
      #expect(RouteGuidanceGeometry.cumulativeDistances(for: [Self.origin]) == [0])
   }

   // MARK: - Locating

   @Test func aPointOnTheLineProjectsToItsDistanceAlong() {
      let line = straightLine(length: 200)
      let cumulative = RouteGuidanceGeometry.cumulativeDistances(for: line)

      let projection = RouteGuidanceGeometry.locate(
         point(east: 130, north: 0),
         on: line,
         cumulative: cumulative,
         in: 0..<(line.count - 1),
         course: -1,
         anchor: nil
      )

      #expect(projection != nil)
      #expect(abs((projection?.distanceAlongRoute ?? 0) - 130) < 3)
      #expect((projection?.lateralDistance ?? 99) < 2)
   }

   @Test func aPointBesideTheLineReportsItsLateralDistance() {
      let line = straightLine(length: 200)
      let cumulative = RouteGuidanceGeometry.cumulativeDistances(for: line)

      let projection = RouteGuidanceGeometry.locate(
         point(east: 100, north: 45),
         on: line,
         cumulative: cumulative,
         in: 0..<(line.count - 1),
         course: -1,
         anchor: nil
      )

      #expect(abs((projection?.lateralDistance ?? 0) - 45) < 3)
      #expect(abs((projection?.distanceAlongRoute ?? 0) - 100) < 3)
   }

   @Test func aLineTooShortToDrawCannotBeProjectedOnto() {
      let single = [Self.origin]

      #expect(
         RouteGuidanceGeometry.locate(
            Self.origin,
            on: single,
            cumulative: [0],
            in: 0..<1,
            course: -1,
            anchor: nil
         ) == nil
      )
   }

   // MARK: - Windows

   @Test func aWindowNarrowsTheSegmentsSearched() {
      let line = straightLine(length: 1_000)
      let cumulative = RouteGuidanceGeometry.cumulativeDistances(for: line)

      let range = RouteGuidanceGeometry.segmentRange(
         from: 400,
         to: 500,
         cumulative: cumulative
      )

      #expect(range.count < line.count / 4)
      #expect(cumulative[range.lowerBound] <= 400)
      #expect(cumulative[min(range.upperBound, cumulative.count - 1)] >= 500)
   }

   @Test func aWindowBeyondTheRouteStaysInsideIt() {
      let line = straightLine(length: 200)
      let cumulative = RouteGuidanceGeometry.cumulativeDistances(for: line)

      let range = RouteGuidanceGeometry.segmentRange(
         from: -500,
         to: 5_000,
         cumulative: cumulative
      )

      #expect(range.lowerBound == 0)
      #expect(range.upperBound == line.count - 1)
   }

   // MARK: - Bearings

   @Test func bearingsFollowTheCompass() {
      #expect(abs(RouteGuidanceGeometry.bearing(from: Self.origin, to: point(east: 0, north: 100))) < 2)
      #expect(abs(RouteGuidanceGeometry.bearing(from: Self.origin, to: point(east: 100, north: 0)) - 90) < 2)
      #expect(abs(RouteGuidanceGeometry.bearing(from: Self.origin, to: point(east: 0, north: -100)) - 180) < 2)
      #expect(abs(RouteGuidanceGeometry.bearing(from: Self.origin, to: point(east: -100, north: 0)) - 270) < 2)
   }

   @Test func bearingDeltaTakesTheShortWayRound() {
      #expect(RouteGuidanceGeometry.bearingDelta(350, 10) == 20)
      #expect(RouteGuidanceGeometry.bearingDelta(90, 270) == 180)
      #expect(RouteGuidanceGeometry.bearingDelta(45, 45) == 0)
   }

   // MARK: - Doubling Back

   /// The failure this whole type exists to prevent: two legs of the same route a
   /// few meters apart, and a rider whose heading is the only thing that says
   /// which one they are on.
   @Test func courseSeparatesTheOutboundAndReturnLegsOfAHairpin() {
      let outbound = straightLine(length: 400, north: 0)
      let inbound = straightLine(length: 400, north: 5).reversed()
      let line = outbound + Array(inbound)
      let cumulative = RouteGuidanceGeometry.cumulativeDistances(for: line)
      let rider = point(east: 100, north: 2)

      let headingEast = RouteGuidanceGeometry.locate(
         rider,
         on: line,
         cumulative: cumulative,
         in: 0..<(line.count - 1),
         course: 90,
         anchor: nil
      )

      let headingWest = RouteGuidanceGeometry.locate(
         rider,
         on: line,
         cumulative: cumulative,
         in: 0..<(line.count - 1),
         course: 270,
         anchor: nil
      )

      #expect(abs((headingEast?.distanceAlongRoute ?? 0) - 100) < 15)
      #expect((headingWest?.distanceAlongRoute ?? 0) > 600)
   }

   /// With no usable course, near-equal candidates resolve to the earliest one: a
   /// rider standing where the route passes twice has not ridden it yet.
   @Test func withoutACourseAnAmbiguousPointResolvesToTheEarlierLeg() {
      let outbound = straightLine(length: 400, north: 0)
      let inbound = straightLine(length: 400, north: 5).reversed()
      let line = outbound + Array(inbound)
      let cumulative = RouteGuidanceGeometry.cumulativeDistances(for: line)

      let projection = RouteGuidanceGeometry.locate(
         point(east: 100, north: 2),
         on: line,
         cumulative: cumulative,
         in: 0..<(line.count - 1),
         course: -1,
         anchor: nil
      )

      #expect(abs((projection?.distanceAlongRoute ?? 0) - 100) < 15)
   }
}

// MARK: - Shared Geography

/// Turns meters into coordinates so guidance tests can describe a route in the
/// units the engine works in.
enum RouteGuidanceTestGeography {

   private static let metersPerDegreeLatitude: Double = 111_320

   static func coordinate(
      east: Double,
      north: Double,
      from origin: CLLocationCoordinate2D
   ) -> CLLocationCoordinate2D {
      let metersPerDegreeLongitude = metersPerDegreeLatitude
         * cos(origin.latitude * .pi / 180)

      return CLLocationCoordinate2D(
         latitude: origin.latitude + north / metersPerDegreeLatitude,
         longitude: origin.longitude + east / metersPerDegreeLongitude
      )
   }
}
