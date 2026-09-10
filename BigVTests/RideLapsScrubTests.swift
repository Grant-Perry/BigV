//
//  RideLapsScrubTests.swift
//  BigVTests
//

import CoreGraphics
import Foundation
import Testing
@testable import BigV

struct RideLapsScrubTests {

   private let frames: [RideSplitID: CGRect] = [
      .lap(1): CGRect(x: 0, y: 0, width: 100, height: 20),
      .lap(2): CGRect(x: 0, y: 28, width: 100, height: 20),
      .climb(1): CGRect(x: 0, y: 56, width: 100, height: 20)
   ]

   @Test func aPointInsideARowSelectsThatSplit() {
      #expect(RideLapsScrub.split(at: CGPoint(x: 40, y: 10), frames: frames) == .lap(1))
      #expect(RideLapsScrub.split(at: CGPoint(x: 40, y: 38), frames: frames) == .lap(2))
      #expect(RideLapsScrub.split(at: CGPoint(x: 40, y: 66), frames: frames) == .climb(1))
   }

   @Test func aGutterBetweenRowsPicksTheNearestRow() {
      #expect(RideLapsScrub.split(at: CGPoint(x: 40, y: 24), frames: frames) == .lap(1))
      #expect(RideLapsScrub.split(at: CGPoint(x: 40, y: 26), frames: frames) == .lap(2))
   }

   @Test func aPointOutsideTheListIsNothing() {
      #expect(RideLapsScrub.split(at: CGPoint(x: 40, y: -4), frames: frames) == nil)
      #expect(RideLapsScrub.split(at: CGPoint(x: 40, y: 90), frames: frames) == nil)
      #expect(RideLapsScrub.split(at: CGPoint(x: 140, y: 10), frames: frames) == nil)
   }

   @Test func emptyFramesSelectNothing() {
      #expect(RideLapsScrub.split(at: CGPoint(x: 10, y: 10), frames: [:]) == nil)
   }
}
