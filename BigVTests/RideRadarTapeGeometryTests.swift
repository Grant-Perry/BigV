//
//  RideRadarTapeGeometryTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

struct RideRadarTapeGeometryTests {

   // MARK: - Near-Field Expansion

   @Test func theRiderSitsAtZero() {
      #expect(RideRadarTapeGeometry.fraction(forDistance: 0) == 0)
   }

   @Test func theNearFieldBoundaryLandsAtItsFraction() {
      #expect(RideRadarTapeGeometry.fraction(forDistance: 40) == 0.6)
   }

   @Test func maxRangeReachesTheFarEdge() {
      #expect(RideRadarTapeGeometry.fraction(forDistance: 140) == 1)
   }

   @Test func theNearFieldIsExpandedNotLinear() {
      // 20 m is 14% of the range but earns 30% of the tape.
      let nearFraction = RideRadarTapeGeometry.fraction(forDistance: 20)
      #expect(abs(nearFraction - 0.3) < 0.0001)

      // 90 m is 64% of the range but sits at 80% of the tape.
      let farFraction = RideRadarTapeGeometry.fraction(forDistance: 90)
      #expect(abs(farFraction - 0.8) < 0.0001)
   }

   @Test func theMappingNeverInverts() {
      var previous = -1.0
      for distance in stride(from: 0.0, through: 140.0, by: 5) {
         let fraction = RideRadarTapeGeometry.fraction(forDistance: distance)
         #expect(fraction > previous)
         previous = fraction
      }
   }

   // MARK: - Clamping

   @Test func distancesBeyondRangeClampToTheFarEdge() {
      #expect(RideRadarTapeGeometry.fraction(forDistance: 500) == 1)
   }

   @Test func negativeDistancesClampToTheRider() {
      #expect(RideRadarTapeGeometry.fraction(forDistance: -3) == 0)
   }

   // MARK: - Screen Positions

   // Rear-view convention (Garmin Edge/Varia): the rider is the TOP of the
   // tape, traffic enters at the bottom and climbs as it closes.

   @Test func theRiderMarkIsAtTheTopOfTheTape() {
      #expect(RideRadarTapeGeometry.yPosition(distance: 0, height: 200) == 0)
   }

   @Test func maxRangeIsAtTheBottomOfTheTape() {
      #expect(RideRadarTapeGeometry.yPosition(distance: 140, height: 200) == 200)
   }

   @Test func theNearFieldOccupiesTheUpperTape() {
      let y = RideRadarTapeGeometry.yPosition(distance: 40, height: 100)
      #expect(abs(y - 60) < 0.0001)
   }

   @Test func aClosingVehicleRisesTowardTheRider() {
      let far = RideRadarTapeGeometry.yPosition(distance: 120, height: 200)
      let near = RideRadarTapeGeometry.yPosition(distance: 15, height: 200)
      #expect(near < far)
   }

   // MARK: - Visibility

   @Test func readingsInsideTheRangeAreVisible() {
      #expect(RideRadarTapeGeometry.isVisible(distance: 0))
      #expect(RideRadarTapeGeometry.isVisible(distance: 140))
   }

   @Test func readingsOutsideTheRangeAreCulled() {
      #expect(!RideRadarTapeGeometry.isVisible(distance: 141))
      #expect(!RideRadarTapeGeometry.isVisible(distance: -1))
   }

   // MARK: - Lateral Hook

   @Test func withoutLateralDataEverythingRidesTheCenterline() {
      #expect(RideRadarTapeGeometry.laneX(lateralOffset: nil, width: 48) == 24)
   }

   @Test func lateralOffsetsClampInsideTheTape() {
      let x = RideRadarTapeGeometry.laneX(lateralOffset: 99, width: 48)
      #expect(x <= 48)
      #expect(x > 24)
   }
}
