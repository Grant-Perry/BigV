//
//  RideWatchConnectivityEvent.swift
//  BigVShared
//

import Foundation

/// Everything `WCSession` can tell us, reduced to values that cross actors.
///
/// The delegate fires on an arbitrary queue with non-`Sendable` dictionaries.
/// These events are what the relay yields instead, so both link managers consume
/// an `AsyncStream` and no delegate callback ever reaches the rest of BigV.
nonisolated enum RideWatchConnectivityEvent: Sendable {

   /// Activation, reachability or counterpart availability moved. The manager
   /// re-reads the session rather than trusting a snapshot taken off-actor.
   case linkChanged

   /// iOS only: the session deactivated because the rider switched Watches. It
   /// must be activated again to bind to the new one.
   case needsReactivation

   /// A payload arrived with no channel to answer on.
   case received(RideWatchMessage)

   /// A live message arrived and the counterpart is waiting for a reply.
   case receivedAnswerable(RideWatchMessage, reply: RideWatchReplyBox)

   /// A send failed. Carries the description because logging happens on the
   /// main actor, never on the delegate queue.
   case deliveryFailed(String)
}
