//
//  RideWatchLinkState.swift
//  BigVShared
//

import Foundation

/// The health of the wrist-to-phone link, as one value a view can render.
///
/// WatchConnectivity reports link health across five unrelated properties, three
/// of which only exist on iOS. `resolve` collapses them into a single ordered
/// answer so neither side has to reason about the combinations, and so the
/// mapping can be tested without a paired Watch.
nonisolated enum RideWatchLinkState: String, Sendable, CaseIterable {

   /// This device cannot talk to a Watch at all — iPad, or Simulator without a
   /// paired watch.
   case unsupported

   /// Activation has not finished. Nothing can be sent yet.
   case activating

   /// No Apple Watch is paired with this phone.
   case notPaired

   /// A Watch is paired but BigV is not installed on it.
   case appNotInstalled

   /// Linked, but the counterpart is asleep or out of range. Latest-state
   /// updates still get through; live messages do not.
   case unreachable

   /// Live. Messages land immediately.
   case connected

   // MARK: - Resolution

   /// Collapses a `WCSession` snapshot into one state.
   ///
   /// Pairing and installation are only meaningful once activation has finished,
   /// so activation is checked first. On watchOS those two facts do not exist —
   /// the Watch side passes `true` for both and lets reachability speak.
   static func resolve(
      isSupported: Bool,
      activation: RideWatchActivation,
      isPaired: Bool,
      isCompanionAppInstalled: Bool,
      isReachable: Bool
   ) -> RideWatchLinkState {
      guard isSupported else { return .unsupported }
      guard activation == .activated else { return .activating }
      guard isPaired else { return .notPaired }
      guard isCompanionAppInstalled else { return .appNotInstalled }

      return isReachable ? .connected : .unreachable
   }

   // MARK: - Capability

   /// Whether a live message stands a chance of being delivered.
   var allowsLiveMessages: Bool { self == .connected }

   /// Whether latest-state-wins updates are worth queueing. Unreachable still
   /// counts: the application context is exactly what survives it.
   var allowsQueuedUpdates: Bool {
      switch self {
         case .unreachable, .connected: true
         case .unsupported, .activating, .notPaired, .appNotInstalled: false
      }
   }

   // MARK: - Presentation

   /// Wrist-sized status. `nil` once the link is healthy enough to say nothing.
   var message: String? {
      switch self {
         case .unsupported: "No Watch support"
         case .activating: "Linking…"
         case .notPaired: "No Watch paired"
         case .appNotInstalled: "Install BigVelo on Watch"
         case .unreachable: "Phone out of range"
         case .connected: nil
      }
   }
}
