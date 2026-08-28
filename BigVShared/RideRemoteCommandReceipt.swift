//
//  RideRemoteCommandReceipt.swift
//  BigVShared
//

import Foundation

/// The phone's answer to a remote command: what it did, and the phase it landed
/// in afterwards.
///
/// The phase travels back with the outcome so a wrist tap feels instant instead
/// of waiting for the next mirror tick to confirm it landed.
nonisolated struct RideRemoteCommandReceipt: Sendable, Equatable {

   let outcome: RideRemoteCommandOutcome
   let phase: RidePhase

   // MARK: - Initialization

   init(outcome: RideRemoteCommandOutcome, phase: RidePhase) {
      self.outcome = outcome
      self.phase = phase
   }

   // MARK: - Wire Format

   private enum Key {
      static let outcome = "outcome"
      static let phase = "phase"
   }

   var body: [String: Any] {
      [
         Key.outcome: outcome.rawValue,
         Key.phase: phase.rawValue
      ]
   }

   init?(body: [String: Any]) {
      guard let rawOutcome = body[Key.outcome] as? String,
            let outcome = RideRemoteCommandOutcome(rawValue: rawOutcome),
            let rawPhase = body[Key.phase] as? String,
            let phase = RidePhase(rawValue: rawPhase)
      else { return nil }

      self.outcome = outcome
      self.phase = phase
   }
}
