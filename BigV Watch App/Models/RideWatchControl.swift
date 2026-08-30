//
//  RideWatchControl.swift
//  BigV Watch App
//

import Foundation

/// One button the wrist can offer, already resolved for the current phase.
///
/// The view model builds these so the view never maps a `RidePhase` to a title —
/// the same reason the phone's control bar reads off `RideViewModel`.
nonisolated struct RideWatchControl: Identifiable, Sendable {

   /// The transport glyph a control wears. These buttons are icon-only, so this
   /// is the entire visible label and `title` survives as the spoken one.
   enum Glyph: String, Sendable {
      case play = "play.fill"
      case pause = "pause.fill"
      case stop = "stop.fill"
      case cancel = "xmark"
   }

   let command: RideRemoteCommand
   let title: String
   let glyph: Glyph
   let role: RideWatchControlRole

   var id: String { "\(command.rawValue).\(title)" }
}
