//
//  RouteApproachPolicyTests.swift
//  BigVTests
//

import CoreLocation
import Testing
@testable import BigV

struct RouteApproachPolicyTests {

   private static let start = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)

   private func point(east: Double) -> CLLocationCoordinate2D {
      RouteGuidanceTestGeography.coordinate(east: east, north: 0, from: Self.start)
   }

   @Test func aRiderAlreadyAtTheStartDoesNotNeedALeadIn() {
      #expect(RouteApproachPolicy.needsApproach(from: Self.start, to: Self.start) == false)
      #expect(RouteApproachPolicy.needsApproach(from: point(east: 80), to: Self.start) == false)
   }

   @Test func aRiderPastTheParkingLotNeedsALeadIn() {
      #expect(RouteApproachPolicy.needsApproach(from: point(east: 250), to: Self.start))
      #expect(RouteApproachPolicy.needsApproach(from: point(east: 8_000), to: Self.start))
   }

   @Test func anUnusableFixNeverAsksForALeadIn() {
      let nullIsland = CLLocationCoordinate2D(latitude: 0, longitude: 0)

      #expect(RouteApproachPolicy.needsApproach(from: nullIsland, to: Self.start) == false)
      #expect(RouteApproachPolicy.needsApproach(from: Self.start, to: nullIsland) == false)
   }
}
