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

   let command: RideRemoteCommand
   let title: String
   let role: RideWatchControlRole

   var id: String { "\(command.rawValue).\(title)" }
}
