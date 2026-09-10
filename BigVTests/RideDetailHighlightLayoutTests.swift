//
//  RideDetailHighlightLayoutTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

struct RideDetailHighlightLayoutTests {

   @Test func highlightingKeepsTheStackAboveTheLapsCardTheSameHeight() {
      let hero: CGFloat = 172
      let spacing = RideDetailHighlightLayout.stackSpacing
      let resting = RideDetailHighlightLayout.restingMapHeight + spacing + hero + spacing
      let highlighting = RideDetailHighlightLayout.mapHeight(isHighlighting: true, heroHeight: hero)
         + spacing

      #expect(resting == highlighting)
   }

   @Test func theRestingMapDoesNotGrow() {
      #expect(
         RideDetailHighlightLayout.mapHeight(isHighlighting: false, heroHeight: 200)
            == RideDetailHighlightLayout.restingMapHeight
      )
   }
}
