//
//  RideSplitID.swift
//  BigV
//

import Foundation

/// One row in Laps & Climbs, typed so lap 1 and climb 1 can never collide.
enum RideSplitID: Hashable, Sendable {
   case lap(Int)
   case climb(Int)

   var accessibilityName: String {
      switch self {
      case .lap(let index): "Lap \(index)"
      case .climb(let index): "Climb \(index)"
      }
   }

   var accessibilityIdentifier: String {
      switch self {
      case .lap(let index): "detail.split.lap.\(index)"
      case .climb(let index): "detail.split.climb.\(index)"
      }
   }
}
