//
//  RideRadarTapeGeometry.swift
//  BigV
//

import Foundation

/// Positions vehicle pips on the radar tape.
///
/// Rear-view convention, matching Garmin's Edge/Varia presentation: the rider
/// mark sits at the TOP of the tape, vehicles enter at the bottom (far, behind
/// the rider) and climb toward the rider as they close.
///
/// Pure math with no framework side effects, mirroring `RideHeadingTapeGeometry`:
/// the view draws, this only answers where.
nonisolated enum RideRadarTapeGeometry {

   /// Garmin's own figure for the RTL515: 140 m.
   static let maxRangeMeters: Double = 140

   /// The band that actually matters. A linear 0–140 m map wastes the region
   /// where a rider makes decisions, so the near field is expanded.
   static let nearFieldMeters: Double = 40

   /// How much of the tape the near field occupies.
   static let nearFieldFraction: Double = 0.6

   // MARK: - Mapping

   /// Fraction of the tape between the rider (0) and the far edge (1).
   ///
   /// Piecewise-linear: 0–40 m spreads across the near 60% of the tape,
   /// 40–140 m compresses into the remaining 40%. Clamped at both ends so a
   /// sentinel-adjacent reading can never draw outside the tape.
   static func fraction(forDistance distance: Double) -> Double {
      guard distance > 0 else { return 0 }
      guard distance < maxRangeMeters else { return 1 }

      if distance <= nearFieldMeters {
         return (distance / nearFieldMeters) * nearFieldFraction
      }

      let farProgress = (distance - nearFieldMeters) / (maxRangeMeters - nearFieldMeters)
      return nearFieldFraction + farProgress * (1 - nearFieldFraction)
   }

   /// Y of a vehicle pip in a tape of `height`, measured top-down as SwiftUI
   /// does. Distance zero is the rider mark at the top; max range is the
   /// bottom — a closing vehicle rises toward the rider.
   static func yPosition(distance: Double, height: Double) -> Double {
      guard height > 0 else { return 0 }
      return height * fraction(forDistance: distance)
   }

   /// Whether a reading belongs on the tape at all.
   static func isVisible(distance: Double) -> Bool {
      distance >= 0 && distance <= maxRangeMeters
   }

   // MARK: - Reserved for the 820 V2 stream

   /// X of a pip in a tape of `width`. The RTL515 has no lateral data, so
   /// everything rides the centerline; an 820 path can feed real offsets in
   /// without the view changing.
   static func laneX(lateralOffset: Double?, width: Double, maxOffset: Double = 3) -> Double {
      guard let lateralOffset, maxOffset > 0 else { return width / 2 }
      let clamped = min(max(lateralOffset, -maxOffset), maxOffset)
      return width / 2 + (clamped / maxOffset) * (width / 2 - 4)
   }
}
