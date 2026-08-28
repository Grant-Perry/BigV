//
//  RideRadarThreatTier.swift
//  BigVShared
//

import Foundation

/// How urgently a tracked vehicle deserves the rider's attention.
///
/// The palette follows the industry convention exactly — Garmin, Wahoo, Stages
/// and Hammerhead all agree, and Ride with GPS's inversion of it was called out
/// as a safety bug. Grey or empty means nothing detected; green is reserved for
/// the all-clear transition and is never a steady state with vehicles present.
nonisolated enum RideRadarThreatTier: Int, Sendable, Equatable, Comparable, CaseIterable {

   /// A vehicle is back there, closing at an ordinary rate. Amber.
   case approaching = 1

   /// Advancing at a high rate of speed or about to arrive. Red, plus a
   /// redundant shape cue in every view so the tier is never colour-only.
   case high = 2

   static func < (lhs: RideRadarThreatTier, rhs: RideRadarThreatTier) -> Bool {
      lhs.rawValue < rhs.rawValue
   }
}
