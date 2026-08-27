//
//  PlannedRouteFactoryTests.swift
//  BigVTests
//

import CoreLocation
import Foundation
import Testing
@testable import BigV

@MainActor
struct PlannedRouteFactoryTests {

   // MARK: - Fixtures

   private static let start = CLLocationCoordinate2D(latitude: 37.3000, longitude: -122.0000)
   private static let middle = CLLocationCoordinate2D(latitude: 37.3050, longitude: -122.0000)
   private static let end = CLLocationCoordinate2D(latitude: 37.3100, longitude: -122.0000)

   /// 0.01° of latitude, in meters, by the same equirectangular rule the app uses.
   private static let hundredthDegreeLatitude: Double = 1_111.95

   private static func draft(
      name: String = "Sand Hill Road",
      coordinates: [CLLocationCoordinate2D]? = nil,
      distance: CLLocationDistance = 2_400,
      expectedTravelTime: TimeInterval = 900,
      advisories: [String] = [],
      maneuvers: [PlannedRouteFactory.ManeuverDraft] = []
   ) -> PlannedRouteFactory.Draft {
      PlannedRouteFactory.Draft(
         name: name,
         coordinates: coordinates ?? [start, middle, end],
         distance: distance,
         expectedTravelTime: expectedTravelTime,
         advisories: advisories,
         maneuvers: maneuvers
      )
   }

   private static func route(
      _ draft: PlannedRouteFactory.Draft
   ) -> PlannedRoute? {
      PlannedRouteFactory.route(from: draft, source: .appleMaps)
   }

   // MARK: - Conversion

   @Test func aDraftBecomesARouteCarryingTheProvidersFigures() throws {
      let route = try #require(Self.route(Self.draft(advisories: ["Steep grade"])))

      #expect(route.source == .appleMaps)
      #expect(route.name == "Sand Hill Road")
      #expect(route.coordinates.count == 3)
      #expect(route.distance == 2_400)
      #expect(route.expectedTravelTime == 900)
      #expect(route.advisories == ["Steep grade"])
      #expect(route.isDrawable)
   }

   @Test func theRoutesEndpointsAreItsFirstAndLastCoordinates() throws {
      let route = try #require(Self.route(Self.draft()))

      #expect(route.startCoordinate?.latitude == Self.start.latitude)
      #expect(route.endCoordinate?.latitude == Self.end.latitude)
   }

   @Test func namesAndAdvisoriesAreTrimmedAndBlankAdvisoriesDropped() throws {
      let route = try #require(
         Self.route(
            Self.draft(
               name: "  Page Mill Road \n",
               advisories: ["  Gravel section  ", "   ", ""]
            )
         )
      )

      #expect(route.name == "Page Mill Road")
      #expect(route.advisories == ["Gravel section"])
      #expect(route.hasAdvisories)
   }

   // MARK: - Unrideable Drafts

   @Test func aDraftWithNoGeometryIsNotARoute() {
      #expect(Self.route(Self.draft(coordinates: [])) == nil)
   }

   @Test func aSinglePointDraftIsNotARoute() {
      #expect(Self.route(Self.draft(coordinates: [Self.start])) == nil)
   }

   @Test func nullIslandAndInvalidCoordinatesAreDiscarded() throws {
      let route = try #require(
         Self.route(
            Self.draft(
               coordinates: [
                  Self.start,
                  CLLocationCoordinate2D(latitude: 0, longitude: 0),
                  CLLocationCoordinate2D(latitude: .nan, longitude: -122),
                  CLLocationCoordinate2D(latitude: 91, longitude: -122),
                  Self.end
               ]
            )
         )
      )

      #expect(route.coordinates.count == 2)
   }

   @Test func aDraftLeftWithOnePointAfterFilteringIsNotARoute() {
      let coordinates = [
         Self.start,
         CLLocationCoordinate2D(latitude: 0, longitude: 0)
      ]

      #expect(Self.route(Self.draft(coordinates: coordinates)) == nil)
   }

   // MARK: - Distance

   @Test func aMissingProviderDistanceIsMeasuredFromTheGeometry() throws {
      let route = try #require(
         Self.route(Self.draft(coordinates: [Self.start, Self.end], distance: 0))
      )

      #expect(abs(route.distance - Self.hundredthDegreeLatitude) < 1)
   }

   @Test func aNonsenseProviderDistanceIsMeasuredFromTheGeometry() throws {
      let route = try #require(
         Self.route(Self.draft(coordinates: [Self.start, Self.end], distance: .nan))
      )

      #expect(abs(route.distance - Self.hundredthDegreeLatitude) < 1)
   }

   @Test func aNegativeProviderDistanceIsMeasuredFromTheGeometry() throws {
      let route = try #require(
         Self.route(Self.draft(coordinates: [Self.start, Self.end], distance: -500))
      )

      #expect(route.distance > 0)
   }

   // MARK: - Travel Time

   @Test func travelTimeIsNeverNegativeOrNonFinite() throws {
      let negative = try #require(Self.route(Self.draft(expectedTravelTime: -60)))
      #expect(negative.expectedTravelTime == 0)

      let infinite = try #require(Self.route(Self.draft(expectedTravelTime: .infinity)))
      #expect(infinite.expectedTravelTime == 0)
   }

   // MARK: - Maneuvers

   @Test func stepsBecomeManeuversWithCumulativeOffsets() throws {
      let route = try #require(
         Self.route(
            Self.draft(
               maneuvers: [
                  .init(instruction: "Head north on Foothill", distance: 400, coordinates: [Self.start]),
                  .init(instruction: "Turn right onto Page Mill", distance: 600, coordinates: [Self.middle]),
                  .init(instruction: "Arrive", distance: 0, coordinates: [Self.end])
               ]
            )
         )
      )

      #expect(route.maneuvers.count == 3)
      #expect(route.maneuvers.map(\.id) == [0, 1, 2])
      #expect(route.maneuvers.map(\.distance) == [400, 600, 0])
      #expect(route.maneuvers.map(\.distanceFromStart) == [0, 400, 1_000])
      #expect(route.maneuvers[1].instruction == "Turn right onto Page Mill")
      #expect(route.maneuvers[1].coordinate.latitude == Self.middle.latitude)
   }

   @Test func anInstructionlessStepIsDroppedButStillMovesTheOffset() throws {
      let route = try #require(
         Self.route(
            Self.draft(
               maneuvers: [
                  .init(instruction: "  ", distance: 250, coordinates: [Self.start]),
                  .init(instruction: "Turn left onto Alpine", distance: 800, coordinates: [Self.middle])
               ]
            )
         )
      )

      #expect(route.maneuvers.count == 1)
      #expect(route.maneuvers[0].id == 0)
      #expect(route.maneuvers[0].distanceFromStart == 250)
   }

   @Test func aStepWithNoUsableGeometryIsDroppedButStillMovesTheOffset() throws {
      let route = try #require(
         Self.route(
            Self.draft(
               maneuvers: [
                  .init(instruction: "Head north", distance: 300, coordinates: []),
                  .init(
                     instruction: "Turn right",
                     distance: 500,
                     coordinates: [CLLocationCoordinate2D(latitude: 0, longitude: 0)]
                  ),
                  .init(instruction: "Arrive", distance: 0, coordinates: [Self.end])
               ]
            )
         )
      )

      #expect(route.maneuvers.count == 1)
      #expect(route.maneuvers[0].instruction == "Arrive")
      #expect(route.maneuvers[0].distanceFromStart == 800)
   }

   @Test func aStepUsesItsFirstUsableCoordinateAsTheManeuverPoint() throws {
      let route = try #require(
         Self.route(
            Self.draft(
               maneuvers: [
                  .init(
                     instruction: "Turn right",
                     distance: 120,
                     coordinates: [
                        CLLocationCoordinate2D(latitude: 0, longitude: 0),
                        Self.middle,
                        Self.end
                     ]
                  )
               ]
            )
         )
      )

      #expect(route.maneuvers[0].coordinate.latitude == Self.middle.latitude)
   }

   @Test func aBlankNoticeBecomesNoNoticeAtAll() throws {
      let route = try #require(
         Self.route(
            Self.draft(
               maneuvers: [
                  .init(instruction: "Cross the tracks", notice: "   ", distance: 40, coordinates: [Self.start]),
                  .init(
                     instruction: "Continue",
                     notice: " Do not cross when lights flash ",
                     distance: 40,
                     coordinates: [Self.middle]
                  )
               ]
            )
         )
      )

      #expect(route.maneuvers[0].notice == nil)
      #expect(route.maneuvers[1].notice == "Do not cross when lights flash")
   }

   @Test func aNegativeOrNonFiniteStepLengthNeverMovesTheOffsetBackwards() throws {
      let route = try #require(
         Self.route(
            Self.draft(
               maneuvers: [
                  .init(instruction: "Head north", distance: -300, coordinates: [Self.start]),
                  .init(instruction: "Turn right", distance: .nan, coordinates: [Self.middle]),
                  .init(instruction: "Arrive", distance: 100, coordinates: [Self.end])
               ]
            )
         )
      )

      #expect(route.maneuvers.map(\.distance) == [0, 0, 100])
      #expect(route.maneuvers.map(\.distanceFromStart) == [0, 0, 0])
   }

   @Test func aRouteWithoutStepsIsStillRideable() throws {
      let route = try #require(Self.route(Self.draft(maneuvers: [])))

      #expect(route.maneuvers.isEmpty)
      #expect(route.isDrawable)
   }
}
