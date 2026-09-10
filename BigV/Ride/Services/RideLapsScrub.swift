//
//  RideLapsScrub.swift
//  BigV
//

import CoreGraphics
import Foundation

/// Maps a finger on the Laps & Climbs list onto a split.
enum RideLapsScrub {

   /// Hits the row under `point`, or the nearest row when the finger is in a
   /// gutter between rows. Returns `nil` outside the list's bounds.
   static func split(at point: CGPoint, frames: [RideSplitID: CGRect]) -> RideSplitID? {
      if let exact = frames.first(where: { $0.value.contains(point) }) {
         return exact.key
      }

      let ordered = frames.sorted { $0.value.minY < $1.value.minY }
      guard let first = ordered.first?.value, let last = ordered.last?.value else {
         return nil
      }

      let minX = ordered.map(\.value.minX).min() ?? first.minX
      let maxX = ordered.map(\.value.maxX).max() ?? first.maxX
      let slop: CGFloat = 8

      guard point.x >= minX - slop, point.x <= maxX + slop else { return nil }
      guard point.y >= first.minY, point.y <= last.maxY else { return nil }

      return ordered.min { lhs, rhs in
         abs(lhs.value.midY - point.y) < abs(rhs.value.midY - point.y)
      }?.key
   }
}
