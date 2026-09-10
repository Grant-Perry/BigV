//
//  RideDetailHighlightLayout.swift
//  BigV
//

import CoreGraphics
import Foundation

/// Keeps the Laps & Climbs card pinned while the map eats the hero.
///
/// Resting stack: map + gutter + hero + gutter.
/// Highlight stack: grown map + gutter + collapsed hero.
/// Grow by hero + one gutter so the two sums match and the list does not jump.
enum RideDetailHighlightLayout {

   static let restingMapHeight: CGFloat = 300
   static let stackSpacing: CGFloat = 14

   /// Used until the hero has been measured on screen.
   static let fallbackHeroHeight: CGFloat = 168

   static func mapHeight(isHighlighting: Bool, heroHeight: CGFloat) -> CGFloat {
      guard isHighlighting else { return restingMapHeight }
      return restingMapHeight + heroHeight + stackSpacing
   }
}
