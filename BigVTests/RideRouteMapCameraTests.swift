//
//  RideRouteMapCameraTests.swift
//  BigVTests
//

import CoreLocation
import Foundation
import MapKit
import Testing
@testable import BigV

struct RideRouteMapCameraTests {

   private static let origin = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
   private static let farther = CLLocationCoordinate2D(latitude: 37.3549, longitude: -122.0090)
   private static let near = CLLocationCoordinate2D(latitude: 37.3360, longitude: -122.0090)

   @Test func aHighlightWinsTheCameraRegion() throws {
      let route = RideRoute(coordinates: [Self.origin, Self.farther])
      let slice = RideRoute(coordinates: [Self.origin, Self.near])
      let highlight = RideRouteMapHighlight(segment: RideSplitSegment(id: .lap(3), route: slice))

      let region = try #require(RideRouteMapCamera.region(highlight: highlight, route: route))
      let sliceRegion = try #require(slice.region)

      #expect(abs(region.center.latitude - sliceRegion.center.latitude) < 0.0001)
      #expect(region.span.latitudeDelta < (route.region?.span.latitudeDelta ?? 1))
   }

   @Test func theWholeRideFramesWhenNothingIsPinned() throws {
      let route = RideRoute(coordinates: [Self.origin, Self.farther])
      let region = try #require(RideRouteMapCamera.region(highlight: nil, route: route))

      #expect(abs(region.center.latitude - (route.region?.center.latitude ?? 0)) < 0.0001)
   }
}
