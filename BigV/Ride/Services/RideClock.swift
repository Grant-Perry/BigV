//
//  RideClock.swift
//  BigV
//

import Foundation

/// Tracks how long a ride has actually been running.
///
/// Elapsed time is wall time since the first GPS fix, less every pause — including
/// one that is still open, so a paused rider does not watch the timer keep
/// climbing.
///
/// Pure and value-typed so the arithmetic is testable without a session, a
/// location stream, or a real second passing.
struct RideClock: Sendable {

   // MARK: - Private State

   /// Time already absorbed by pauses that have been closed.
   private var pausedDuration: TimeInterval = 0

   /// When the current pause began, if one is open.
   private var pauseStartedAt: Date?

   // MARK: - Pausing

   mutating func beginPause(at date: Date = .now) {
      guard pauseStartedAt == nil else { return }
      pauseStartedAt = date
   }

   /// Closes an open pause and folds it into the running total. Safe to call
   /// when no pause is open, which is what ending a ride mid-pause relies on.
   mutating func endPause(at date: Date = .now) {
      guard let pauseStartedAt else { return }

      pausedDuration += date.timeIntervalSince(pauseStartedAt)
      self.pauseStartedAt = nil
   }

   // MARK: - Reset

   mutating func reset() {
      pausedDuration = 0
      pauseStartedAt = nil
   }

   // MARK: - Restore

   /// Re-anchors the clock onto a ride that was interrupted and is being picked
   /// back up.
   ///
   /// Everything between the last recorded second and now is time the app was
   /// not running, so it is charged to pauses. Ride time therefore resumes at
   /// the figure the rider last saw rather than jumping by however long the
   /// phone spent doing something else.
   mutating func restore(
      elapsed: TimeInterval,
      since startDate: Date,
      at reference: Date = .now
   ) {
      pauseStartedAt = nil
      pausedDuration = max(0, reference.timeIntervalSince(startDate) - max(0, elapsed))
   }

   // MARK: - Elapsed

   /// Wall time from `startDate` to `reference`, less every pause.
   func elapsed(since startDate: Date, at reference: Date = .now) -> TimeInterval {
      var elapsed = reference.timeIntervalSince(startDate) - pausedDuration

      if let pauseStartedAt {
         elapsed -= reference.timeIntervalSince(pauseStartedAt)
      }

      return max(0, elapsed)
   }
}
