//
//  RideRouteBoundsTests.swift
//  BigVTests
//

import CoreLocation
import Foundation
import MapKit
import Testing
@testable import BigV

@MainActor
struct RideRouteBoundsTests {

   // MARK: - Fixtures

   private static let origin = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)

   private static let tolerance = 1e-9

   // MARK: - Fitting

   @Test func regionFramesTheRouteBoundingBox() throws {
      let coordinates = [
         CLLocationCoordinate2D(latitude: 37.30, longitude: -122.10),
         CLLocationCoordinate2D(latitude: 37.40, longitude: -122.00),
         CLLocationCoordinate2D(latitude: 37.35, longitude: -122.05)
      ]

      let region = try #require(RideRouteBounds.region(for: coordinates))

      #expect(abs(region.center.latitude - 37.35) < Self.tolerance)
      #expect(abs(region.center.longitude + 122.05) < Self.tolerance)
      #expect(abs(region.span.latitudeDelta - 0.1 * RideRouteBounds.paddingFactor) < Self.tolerance)
      #expect(abs(region.span.longitudeDelta - 0.1 * RideRouteBounds.paddingFactor) < Self.tolerance)
   }

   @Test func regionPadsBeyondTheRouteSoTheLineNeverTouchesTheEdge() throws {
      let coordinates = [
         CLLocationCoordinate2D(latitude: 37.30, longitude: -122.10),
         CLLocationCoordinate2D(latitude: 37.40, longitude: -122.00)
      ]

      let region = try #require(RideRouteBounds.region(for: coordinates))

      #expect(region.span.latitudeDelta > 0.1)
      #expect(region.span.longitudeDelta > 0.1)
   }

   @Test func aRouteWiderThanItIsTallKeepsBothSpansIndependent() throws {
      let coordinates = [
         CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.20),
         CLLocationCoordinate2D(latitude: 37.3400, longitude: -122.00)
      ]

      let region = try #require(RideRouteBounds.region(for: coordinates))

      #expect(region.span.longitudeDelta > region.span.latitudeDelta)
   }

   // MARK: - Degenerate Routes

   @Test func anEmptyRouteHasNoRegion() {
      #expect(RideRouteBounds.region(for: []) == nil)
   }

   @Test func aSinglePointRegionCentersOnItAtTheMinimumSpan() throws {
      let region = try #require(RideRouteBounds.region(for: [Self.origin]))

      #expect(region.center.latitude == Self.origin.latitude)
      #expect(region.center.longitude == Self.origin.longitude)
      #expect(region.span.latitudeDelta == RideRouteBounds.minimumSpan)
      #expect(region.span.longitudeDelta == RideRouteBounds.minimumSpan)
   }

   @Test func aRouteThatNeverLeftTheDrivewayIsClampedToTheMinimumSpan() throws {
      let region = try #require(
         RideRouteBounds.region(for: Array(repeating: Self.origin, count: 40))
      )

      #expect(region.span.latitudeDelta == RideRouteBounds.minimumSpan)
      #expect(region.span.longitudeDelta == RideRouteBounds.minimumSpan)
   }

   // MARK: - Drawability

   @Test func aRouteNeedsTwoPointsBeforeItCanBeDrawn() {
      #expect(RideRoute.empty.isDrawable == false)
      #expect(RideRoute.empty.region == nil)

      #expect(RideRoute(coordinates: [Self.origin]).isDrawable == false)

      let pair = RideRoute(coordinates: [
         Self.origin,
         CLLocationCoordinate2D(latitude: 37.3405, longitude: -122.0012)
      ])
      #expect(pair.isDrawable)
      #expect(pair.startCoordinate?.latitude == Self.origin.latitude)
      #expect(pair.endCoordinate?.latitude == 37.3405)
   }
}
