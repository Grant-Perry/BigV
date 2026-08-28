//
//  RideFormattersTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

struct RideFormattersTests {

   // MARK: - Cardinal

   @Test func anUnknownCourseHasNoCardinal() {
      #expect(RideFormatters.cardinal(-1) == nil)
   }

   @Test func dueNorthIsN() {
      #expect(RideFormatters.cardinal(0) == "N")
      #expect(RideFormatters.cardinal(359) == "N")
   }

   @Test func theFourOrdinalsLandOnTheirPoints() {
      #expect(RideFormatters.cardinal(90) == "E")
      #expect(RideFormatters.cardinal(180) == "S")
      #expect(RideFormatters.cardinal(270) == "W")
   }

   @Test func northeastIsTheHalfwayPoint() {
      #expect(RideFormatters.cardinal(45) == "NE")
   }

   // MARK: - Degrees

   @Test func anUnknownCourseHasNoDegreeReadout() {
      #expect(RideFormatters.headingDegrees(-1) == nil)
   }

   @Test func headingDegreesRoundToTheNearestWholeDegree() {
      #expect(RideFormatters.headingDegrees(47.4) == "47°")
      #expect(RideFormatters.headingDegrees(47.6) == "48°")
   }

   @Test func threeSixtyDegreesReadAsZero() {
      #expect(RideFormatters.headingDegrees(359.6) == "0°")
   }
}
