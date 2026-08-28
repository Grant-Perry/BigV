//
//  RideRemoteCommandAcknowledgement.swift
//  BigVShared
//

import Foundation

/// The way back to the wrist after a remote command has been judged.
///
/// Exists so the session manager can answer the Watch while speaking nothing but
/// domain types — it hands over an outcome and a phase, and the link manager
/// decides how that becomes a WatchConnectivity payload.
nonisolated struct RideRemoteCommandAcknowledgement: Sendable {

   private let respond: @Sendable (RideRemoteCommandOutcome, RidePhase) -> Void

   // MARK: - Initialization

   init(respond: @escaping @Sendable (RideRemoteCommandOutcome, RidePhase) -> Void) {
      self.respond = respond
   }

   /// For commands that arrived with no reply channel, such as a queued transfer.
   static let unanswerable = RideRemoteCommandAcknowledgement { _, _ in }

   // MARK: - Answering

   func callAsFunction(_ outcome: RideRemoteCommandOutcome, phase: RidePhase) {
      respond(outcome, phase)
   }
}
