//
//  RideRetraceRouteBuilderTests.swift
//  BigVTests
//

import CoreLocation
import Foundation
import Testing
@testable import BigV

@MainActor
struct RideRetraceRouteBuilderTests {

   private static let origin = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)

   /// A breadcrumb heading east, one point every 50 meters.
   private func breadcrumb(length: Double) -> [CLLocationCoordinate2D] {
      stride(from: 0, through: length, by: 50).map {
         RouteGuidanceTestGeography.coordinate(east: $0, north: 0, from: Self.origin)
      }
   }

   // MARK: - Reversal

   @Test func theRouteHomeIsTheBreadcrumbBackwards() throws {
      let crumbs = breadcrumb(length: 2_000)

      let route = try #require(RideRetraceRouteBuilder.route(reversing: crumbs))

      #expect(route.source == .retrace)
      #expect(route.name == "Back to Start")
      #expect(route.coordinates.count == crumbs.count)

      // Where the rider is becomes the start; where they began becomes the end.
      let first = try #require(route.coordinates.first)
      let last = try #require(route.coordinates.last)
      #expect(abs(first.longitude - crumbs[crumbs.count - 1].longitude) < 0.000001)
      #expect(abs(last.longitude - crumbs[0].longitude) < 0.000001)
   }

   @Test func distanceIsMeasuredFromTheGeometry() throws {
      // The builder claims no total, so the factory measures the line itself.
      let route = try #require(RideRetraceRouteBuilder.route(reversing: breadcrumb(length: 2_000)))
      #expect(abs(route.distance - 2_000) < 20)
   }

   @Test func aRouteWithoutATimeEstimateSaysSo() throws {
      let route = try #require(RideRetraceRouteBuilder.route(reversing: breadcrumb(length: 1_000)))
      #expect(route.expectedTravelTime == 0)
   }

   // MARK: - Degenerates

   @Test func tooLittleTrackLeadsNowhere() {
      #expect(RideRetraceRouteBuilder.route(reversing: []) == nil)
      #expect(RideRetraceRouteBuilder.route(reversing: [Self.origin]) == nil)
   }
}
