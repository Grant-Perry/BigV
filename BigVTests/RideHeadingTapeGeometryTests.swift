//
//  RideHeadingTapeGeometryTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

struct RideHeadingTapeGeometryTests {

   @Test func negativeDegreesWrapIntoTheCircle() {
      #expect(RideHeadingTapeGeometry.normalized(-90) == 270)
   }

   @Test func threeSixtyCollapsesToZero() {
      #expect(RideHeadingTapeGeometry.normalized(360) == 0)
   }

   @Test func theShortestTurnWestOfNorthIsNegative() {
      let delta = RideHeadingTapeGeometry.signedDelta(from: 10, to: 350)
      #expect(delta == -20)
   }

   @Test func theShortestTurnEastOfNorthIsPositive() {
      let delta = RideHeadingTapeGeometry.signedDelta(from: 350, to: 10)
      #expect(delta == 20)
   }

   @Test func theCurrentCourseSitsAtTheTapeCenter() {
      let x = RideHeadingTapeGeometry.xPosition(
         heading: 90,
         course: 90,
         width: 200,
         visibleSpan: 100
      )
      #expect(x == 100)
   }

   @Test func aHeadingTenDegreesRightOfCourseSitsRightOfCenter() {
      let x = RideHeadingTapeGeometry.xPosition(
         heading: 100,
         course: 90,
         width: 200,
         visibleSpan: 100
      )
      #expect(x == 120)
   }

   @Test func northStaysVisibleWhenTheCourseWrapsPastZero() {
      #expect(
         RideHeadingTapeGeometry.isVisible(heading: 0, course: 350, visibleSpan: 120)
      )
   }
}
