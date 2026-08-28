//
//  RideWatchActivation+WCSession.swift
//  BigVShared
//

import WatchConnectivity

nonisolated extension RideWatchActivation {

   /// Bridges WatchConnectivity's activation state at the framework boundary, so
   /// the link-state machine that consumes it stays free of WatchConnectivity and
   /// therefore testable on its own.
   init(_ activationState: WCSessionActivationState) {
      switch activationState {
         case .notActivated: self = .notActivated
         case .inactive: self = .inactive
         case .activated: self = .activated
         @unknown default: self = .notActivated
      }
   }
}
