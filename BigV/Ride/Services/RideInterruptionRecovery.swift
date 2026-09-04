//
//  RideInterruptionRecovery.swift
//  BigV
//

import Foundation

/// Decides what to do with a ride row the app never closed out.
///
/// A `Ride` exists from the first GPS fix, so an app that is jettisoned mid-ride
/// — memory pressure while the rider is in Mail, a crash, a dead battery —
/// leaves a perfectly good row behind with no `endDate`. History only lists
/// finished rides, so without this the ride is on disk and invisible, which
/// reads to the rider as "it never happened".
///
/// Pure and free of side effects so every branch can be proven without a store,
/// a session or a real clock.
enum RideInterruptionRecovery {

   // MARK: - Window

   /// How long an interruption may last and still be picked up as the same ride.
   ///
   /// Generous on purpose: an all-day ride that loses the app at hour four must
   /// resume, not restart. Past this the ride is over in every sense that
   /// matters, so it is closed out into history instead.
   static let resumeWindow: TimeInterval = 12 * 3_600

   // MARK: - Decision

   enum Decision: Sendable, Equatable {

      /// Pick the ride back up where it stopped.
      case resume(isPaused: Bool)

      /// Too old to resume, but real: finish it and file it in history.
      case closeOut

      /// Never went anywhere. Erase it rather than leave junk in history.
      case discard(RideRetentionPolicy.DiscardReason)
   }

   // MARK: - Evaluation

   /// - Parameters:
   ///   - checkpoint: What the app was doing when it last wrote one. `nil` for
   ///     any row that is not the newest interruption, and for rows left behind
   ///     by a build that predates checkpoints.
   ///   - rideStartDate: The open row's first-fix date.
   ///   - distance: Ground the row already recorded, in meters.
   ///   - sampleCount: Samples the row already recorded.
   static func decision(
      checkpoint: RideSessionCheckpoint?,
      rideStartDate: Date,
      distance: Double,
      sampleCount: Int,
      now: Date = .now
   ) -> Decision {
      if case .discard(let reason) = RideRetentionPolicy.decision(
         distance: distance,
         sampleCount: sampleCount
      ) {
         return .discard(reason)
      }

      guard let checkpoint,
            checkpoint.phase.isActive,
            checkpoint.startDate == rideStartDate,
            now.timeIntervalSince(checkpoint.updatedAt) <= resumeWindow,
            now >= checkpoint.updatedAt
      else { return .closeOut }

      return .resume(isPaused: checkpoint.phase == .paused)
   }
}
