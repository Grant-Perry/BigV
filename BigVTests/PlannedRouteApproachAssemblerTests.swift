//
//  PlannedRouteApproachAssemblerTests.swift
//  BigVTests
//

import CoreLocation
import Testing
@testable import BigV

struct PlannedRouteApproachAssemblerTests {

   private static let origin = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)

   private func point(east: Double, north: Double = 0) -> CLLocationCoordinate2D {
      RouteGuidanceTestGeography.coordinate(east: east, north: north, from: Self.origin)
   }

   private func line(from start: Double, to end: Double) -> [CLLocationCoordinate2D] {
      stride(from: start, through: end, by: 20).map { point(east: $0) }
   }

   private func route(
      name: String,
      source: PlannedRouteSource,
      from start: Double,
      to end: Double,
      maneuvers: [PlannedRouteManeuver] = [],
      distance: CLLocationDistance = 0
   ) -> PlannedRoute {
      PlannedRoute(
         id: UUID(),
         source: source,
         name: name,
         coordinates: line(from: start, to: end),
         distance: distance,
         expectedTravelTime: 120,
         maneuvers: maneuvers,
         advisories: []
      )
   }

   @Test func approachAndCourseBecomeOneLine() throws {
      let approach = route(name: "Warwick Blvd", source: .appleMaps, from: 0, to: 200)
      let course = route(name: "Noland Trail", source: .gpx, from: 200, to: 400)

      let stitched = try #require(
         PlannedRouteApproachAssembler.stitched(approach: approach, course: course)
      )

      #expect(stitched.source == .gpx)
      #expect(stitched.name == "Noland Trail")
      #expect(stitched.hasApproach)
      #expect(abs(stitched.approachDistance - 200) < 4)
      #expect(abs(stitched.distance - 400) < 6)
      #expect(stitched.expectedTravelTime == 240)
      #expect(stitched.startCoordinate?.latitude == approach.startCoordinate?.latitude)
      #expect(stitched.endCoordinate?.latitude == course.endCoordinate?.latitude)
   }

   @Test func aSharedJoinPointIsNotDuplicated() throws {
      let approach = route(name: "Lead In", source: .appleMaps, from: 0, to: 100)
      let course = route(name: "Trail", source: .gpx, from: 100, to: 200)

      let stitched = try #require(
         PlannedRouteApproachAssembler.stitched(approach: approach, course: course)
      )

      #expect(stitched.coordinates.count == approach.coordinates.count + course.coordinates.count - 1)
   }

   @Test func courseManeuversShiftByTheLeadIn() throws {
      let start = point(east: 200)
      let courseManeuver = PlannedRouteManeuver(
         id: 0,
         instruction: "Keep left",
         notice: nil,
         distance: 40,
         distanceFromStart: 20,
         coordinate: start
      )
      let approach = route(name: "Lead In", source: .appleMaps, from: 0, to: 200)
      let course = route(
         name: "Noland Trail",
         source: .gpx,
         from: 200,
         to: 360,
         maneuvers: [courseManeuver]
      )

      let stitched = try #require(
         PlannedRouteApproachAssembler.stitched(approach: approach, course: course)
      )

      #expect(stitched.maneuvers.contains { $0.instruction == "Start of Noland Trail" })

      let shifted = try #require(stitched.maneuvers.first { $0.instruction == "Keep left" })
      #expect(abs(shifted.distanceFromStart - (stitched.approachDistance + 20)) < 1)
   }

   @Test func aBlankCourseIsNotStitched() {
      let approach = route(name: "Lead In", source: .appleMaps, from: 0, to: 100)
      let empty = PlannedRoute(
         id: UUID(),
         source: .gpx,
         name: "Empty",
         coordinates: [point(east: 100)],
         distance: 0,
         expectedTravelTime: 0,
         maneuvers: [],
         advisories: []
      )

      #expect(PlannedRouteApproachAssembler.stitched(approach: approach, course: empty) == nil)
   }
}
