//
//  RideRemoteCommandValidator.swift
//  BigVShared
//

import Foundation

/// Decides whether the phone should act on a command that arrived from the wrist.
///
/// Pure so the whole decision table is testable without a paired Watch. Two
/// things can disqualify a command: it is stale, or the ride is in a phase that
/// has no use for it.
nonisolated enum RideRemoteCommandValidator {

   /// How long a command still counts as rider intent.
   ///
   /// Sized for a queued delivery that lands after a brief unreachable spell,
   /// not for one that surfaces at the end of a ride. A START that shows up two
   /// minutes late would begin a ride nobody asked for.
   static let freshnessWindow: TimeInterval = 15

   // MARK: - Evaluation

   static func evaluate(
      _ request: RideRemoteCommandRequest,
      phase: RidePhase,
      now: Date = .now,
      freshnessWindow: TimeInterval = freshnessWindow
   ) -> RideRemoteCommandOutcome {
      // Absolute value catches clock skew in both directions: a Watch running
      // ahead of the phone must not be trusted any further than one behind it.
      let age = abs(now.timeIntervalSince(request.sentAt))
      guard age <= freshnessWindow else { return .expired }
      guard request.command.isPermitted(in: phase) else { return .ignoredForPhase }

      return .accepted
   }
}
