//
//  RideWatchConnectivityRelay.swift
//  BigVShared
//

import Foundation
import WatchConnectivity

/// The only `WCSessionDelegate` in BigV.
///
/// WatchConnectivity is a queue-hopping, closure-shaped, Objective-C API. This
/// relay absorbs all of that: it decodes payloads into `RideWatchMessage` values
/// and yields them into an `AsyncStream`, so both link managers see nothing but
/// `async`/`await`. Shared by phone and Watch because the delegate work is
/// identical apart from the three iOS-only callbacks below.
///
/// Deliberately `nonisolated`: these callbacks arrive on a private WatchConnectivity
/// queue, and pretending otherwise would either lie to the compiler or force a
/// hop before the payload has even been read. `AsyncStream.Continuation` is
/// thread-safe, which is the whole reason it is the hand-off point.
nonisolated final class RideWatchConnectivityRelay: NSObject, WCSessionDelegate, @unchecked Sendable {

   // MARK: - Private Properties

   private let continuation: AsyncStream<RideWatchConnectivityEvent>.Continuation

   // MARK: - Initialization

   init(continuation: AsyncStream<RideWatchConnectivityEvent>.Continuation) {
      self.continuation = continuation
      super.init()
   }

   // MARK: - Activation

   func session(
      _ session: WCSession,
      activationDidCompleteWith activationState: WCSessionActivationState,
      error: Error?
   ) {
      if let error {
         continuation.yield(.deliveryFailed("Activation failed: \(error.localizedDescription)"))
      }

      continuation.yield(.linkChanged)
   }

   #if os(iOS)

   func sessionDidBecomeInactive(_ session: WCSession) {
      continuation.yield(.linkChanged)
   }

   /// The rider switched to a different Apple Watch. Rebinding is mandatory or
   /// the phone keeps talking to a Watch that is no longer on the wrist.
   func sessionDidDeactivate(_ session: WCSession) {
      continuation.yield(.needsReactivation)
   }

   func sessionWatchStateDidChange(_ session: WCSession) {
      continuation.yield(.linkChanged)
   }

   #endif

   // MARK: - Reachability

   func sessionReachabilityDidChange(_ session: WCSession) {
      continuation.yield(.linkChanged)
   }

   // MARK: - Receiving

   func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
      yield(message, reply: nil)
   }

   func session(
      _ session: WCSession,
      didReceiveMessage message: [String: Any],
      replyHandler: @escaping ([String: Any]) -> Void
   ) {
      yield(message, reply: RideWatchReplyBox(replyHandler))
   }

   func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
      yield(applicationContext, reply: nil)
   }

   func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
      yield(userInfo, reply: nil)
   }

   // MARK: - Decoding

   /// An undecodable payload is dropped rather than escalated: a counterpart on a
   /// newer build must never be able to break this one.
   private func yield(_ payload: [String: Any], reply: RideWatchReplyBox?) {
      guard let message = RideWatchMessage(payload: payload) else { return }

      if let reply {
         continuation.yield(.receivedAnswerable(message, reply: reply))
      } else {
         continuation.yield(.received(message))
      }
   }

   // MARK: - Teardown

   func finish() {
      continuation.finish()
   }
}
