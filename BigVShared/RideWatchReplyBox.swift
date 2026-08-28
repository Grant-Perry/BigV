//
//  RideWatchReplyBox.swift
//  BigVShared
//

import Foundation

/// Carries a `WCSession` reply handler off the delegate queue.
///
/// WatchConnectivity hands back a bare escaping closure, documented as callable
/// from any queue. Boxing it lets the answer be sent *after* the main actor has
/// actually decided what happened, rather than guessing from the delegate queue.
///
/// `@unchecked` because the closure comes from an Objective-C API that carries no
/// sendability information. Nothing else is stored, and the closure is only ever
/// called once.
nonisolated struct RideWatchReplyBox: @unchecked Sendable {

   private let deliver: ([String: Any]) -> Void

   // MARK: - Initialization

   init(_ deliver: @escaping ([String: Any]) -> Void) {
      self.deliver = deliver
   }

   /// For payloads that arrived with no way to answer — a queued transfer or an
   /// application-context update.
   static let unanswerable = RideWatchReplyBox { _ in }

   // MARK: - Sending

   func callAsFunction(_ message: RideWatchMessage) {
      deliver(message.payload)
   }
}
