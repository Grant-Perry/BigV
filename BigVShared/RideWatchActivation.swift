//
//  RideWatchActivation.swift
//  BigVShared
//

import Foundation

/// How far along `WCSession` activation has got.
///
/// A local mirror of `WCSessionActivationState` so the state machine that reads
/// it stays free of WatchConnectivity and therefore testable on its own.
nonisolated enum RideWatchActivation: Sendable, CaseIterable {

   case notActivated
   case inactive
   case activated
}
