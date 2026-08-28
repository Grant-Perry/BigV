//
//  RideRemoteCommandOutcome.swift
//  BigVShared
//

import Foundation

/// What became of a command the wrist sent.
nonisolated enum RideRemoteCommandOutcome: String, Sendable, CaseIterable {

   /// The phone acted on it.
   case accepted

   /// The phone was in a phase that rejects this command.
   case ignoredForPhase

   /// The command sat in a queue too long to still represent rider intent.
   case expired

   /// The phone never heard it. Produced on the Watch when the transport fails,
   /// never sent over the wire.
   case undelivered

   // MARK: - Presentation

   /// Wrist-sized explanation. `nil` when there is nothing worth interrupting
   /// the rider for.
   var message: String? {
      switch self {
         case .accepted: nil
         case .ignoredForPhase: "Phone ignored that"
         case .expired: "Too late — try again"
         case .undelivered: "Phone unreachable"
      }
   }
}
