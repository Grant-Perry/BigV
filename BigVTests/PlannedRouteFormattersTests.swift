//
//  PlannedRouteFormattersTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

@MainActor
struct PlannedRouteFormattersTests {

   // MARK: - Travel Time

   @Test func aShortRideReadsInMinutes() {
      #expect(PlannedRouteFormatters.travelTime(18 * 60) == "18 min")
   }

   /// A route Apple thinks takes twenty seconds still has to say something a
   /// rider can read, and "0 min" is not it.
   @Test func aRideTooShortToMeasureStillReadsAsAMinute() {
      #expect(PlannedRouteFormatters.travelTime(20) == "1 min")
      #expect(PlannedRouteFormatters.travelTime(0) == "1 min")
   }

   @Test func anHourLongRideReadsInHoursAndMinutes() {
      #expect(PlannedRouteFormatters.travelTime(65 * 60) == "1 hr 5 min")
      #expect(PlannedRouteFormatters.travelTime(150 * 60) == "2 hr 30 min")
   }

   @Test func aWholeNumberOfHoursDropsTheMinutes() {
      #expect(PlannedRouteFormatters.travelTime(2 * 3_600) == "2 hr")
   }

   @Test func aNegativeTravelTimeIsNotShownAsNegative() {
      #expect(PlannedRouteFormatters.travelTime(-600) == "1 min")
   }

   // MARK: - Distance

   @Test func distanceReadsInMilesWithItsUnit() {
      #expect(PlannedRouteFormatters.distance(1_609.344) == "1.00 MI")
      #expect(PlannedRouteFormatters.distance(0) == "0.00 MI")
   }
}
