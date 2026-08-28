//
//  RideRemoteCommandRequest.swift
//  BigVShared
//

import Foundation

/// A remote command plus the instant the wrist sent it.
///
/// The timestamp exists so a command that was queued while the phone was
/// unreachable cannot start a ride minutes after the rider asked for one.
/// `RideRemoteCommandValidator` enforces that window.
nonisolated struct RideRemoteCommandRequest: Sendable, Equatable {

   let command: RideRemoteCommand
   let sentAt: Date

   // MARK: - Initialization

   init(command: RideRemoteCommand, sentAt: Date = .now) {
      self.command = command
      self.sentAt = sentAt
   }

   // MARK: - Wire Format

   private enum Key {
      static let command = "command"
      static let sentAt = "sentAt"
   }

   var body: [String: Any] {
      [
         Key.command: command.rawValue,
         Key.sentAt: sentAt.timeIntervalSince1970
      ]
   }

   init?(body: [String: Any]) {
      guard let rawCommand = body[Key.command] as? String,
            let command = RideRemoteCommand(rawValue: rawCommand),
            let sentAt = body[Key.sentAt] as? Double
      else { return nil }

      self.command = command
      self.sentAt = Date(timeIntervalSince1970: sentAt)
   }
}
