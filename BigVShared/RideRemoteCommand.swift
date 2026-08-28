//
//  RideRemoteCommand.swift
//  BigVShared
//

import Foundation

/// A lifecycle instruction sent from the wrist to the phone.
///
/// The Watch is a remote, never the computer: it asks the phone to change phase
/// and the phone decides. `RideSessionManager` stays the only thing that moves a
/// ride through its lifecycle.
nonisolated enum RideRemoteCommand: String, Sendable, CaseIterable {

   case start
   case pause
   case resume
   case end

   // MARK: - Phase Rules

   /// Whether the phone would act on this command in the given phase.
   ///
   /// These mirror the guards inside `RideSessionManager` so the Watch can tell
   /// the rider their tap was ignored instead of leaving them staring at an
   /// unchanged screen. They are advisory only — the session manager re-checks
   /// every one of them, which is what actually makes commands idempotent.
   func isPermitted(in phase: RidePhase) -> Bool {
      switch self {
         case .start: !phase.isActive
         case .pause: phase == .recording
         case .resume: phase == .paused
         case .end: phase.isActive
      }
   }

   // MARK: - Presentation

   /// Wrist-sized button title.
   var title: String {
      switch self {
         case .start: "START"
         case .pause: "PAUSE"
         case .resume: "RESUME"
         case .end: "END"
      }
   }
}
