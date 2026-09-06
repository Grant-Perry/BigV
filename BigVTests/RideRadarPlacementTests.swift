//
//  RideRadarPlacementTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

struct RideRadarPlacementTests {

   @Test func clockwiseWalksTheBezelInOrder() {
      #expect(RideRadarPlacement.bottom.nextClockwise == .leading)
      #expect(RideRadarPlacement.leading.nextClockwise == .top)
      #expect(RideRadarPlacement.top.nextClockwise == .trailing)
      #expect(RideRadarPlacement.trailing.nextClockwise == .bottom)
   }

   @Test func clockwiseReturnsToTheStartInFourSteps() {
      var placement = RideRadarPlacement.bottom
      for _ in 0..<4 {
         placement = placement.nextClockwise
      }
      #expect(placement == .bottom)
   }
}
