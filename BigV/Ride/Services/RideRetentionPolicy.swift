//
//  RideRetentionPolicy.swift
//  BigV
//

import Foundation

/// Decides whether a finished ride earned its place in history.
///
/// A ride row is created the moment the engine acquires a fix, which is before
/// the rider has turned a pedal. Pressing START and then STOP therefore leaves a
/// perfectly well-formed ride with real samples and no distance, so sample count
/// alone cannot separate junk from a genuine ride.
///
/// Pure and free of side effects so the decision can be reasoned about and
/// tested without a store, a session or a clock.
enum RideRetentionPolicy {

   // MARK: - Thresholds

   /// Meters. No real bike ride covers less ground than this, so the threshold
   /// kills standing-still starts without ever eating a legitimate short ride.
   static let minimumMeaningfulDistance: Double = 50

   // MARK: - Decision

   enum Decision: Sendable, Equatable {
      case keep
      case discard(DiscardReason)
   }

   enum DiscardReason: String, Sendable, Equatable {
      case noSamples
      case insufficientDistance
   }

   // MARK: - Evaluation

   /// - Parameters:
   ///   - distance: Ground covered, in meters.
   ///   - sampleCount: Samples the ride actually recorded.
   static func decision(distance: Double, sampleCount: Int) -> Decision {
      guard sampleCount > 0 else { return .discard(.noSamples) }

      // A NaN distance fails this comparison, which is the outcome we want.
      guard distance >= minimumMeaningfulDistance else {
         return .discard(.insufficientDistance)
      }

      return .keep
   }
}
