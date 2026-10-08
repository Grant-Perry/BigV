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

   /// The phone understood START but recording is locked: the free month is
   /// over and no Plus entitlement is owned. Without this the wrist was told
   /// "accepted" and quietly fell back to idle while the rider pedalled off.
   case accessLocked

   /// START arrived with the app in the background and only When In Use
   /// location, which delivers nothing there. Opening BigVelo on the phone, or
   /// allowing Always location, lifts it.
   case needsPhoneInUse

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
         case .accessLocked: "Unlock BigVelo on iPhone"
         case .needsPhoneInUse: "Open BigVelo on iPhone"
         case .undelivered: "Phone unreachable"
      }
   }
}
