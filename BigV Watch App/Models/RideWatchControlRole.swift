//
//  RideWatchControlRole.swift
//  BigV Watch App
//

import Foundation

/// What a control means, so the view can tint it without knowing about phases.
nonisolated enum RideWatchControlRole: Sendable {

   /// Begin or resume.
   case go

   /// Suspend without finishing.
   case hold

   /// Finish or cancel.
   case stop
}
