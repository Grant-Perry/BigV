//
//  RideAccessPolicy.swift
//  BigV
//

import Foundation

/// Thirty days of the whole product, then pay or read-only.
///
/// Recording, live radar and Watch start follow `canBeginRide`. History, saved
/// routes and export never read this policy.
nonisolated enum RideAccessPolicy {

   static let trialLength: TimeInterval = 30 * 24 * 60 * 60

   enum Status: Equatable, Sendable {
      case subscribed
      case trial(daysRemaining: Int)
      case expired
   }

   static func status(
      trialBeganAt: Date,
      isSubscribed: Bool,
      now: Date = .now
   ) -> Status {
      if isSubscribed { return .subscribed }

      let remaining = trialLength - now.timeIntervalSince(trialBeganAt)
      guard remaining > 0 else { return .expired }

      let days = Int(ceil(remaining / 86_400))
      return .trial(daysRemaining: min(30, max(1, days)))
   }

   static func canBeginRide(_ status: Status) -> Bool {
      switch status {
         case .subscribed, .trial: true
         case .expired: false
      }
   }
}

/// The session asks this before START. Tests and previews omit it and ride freely.
@MainActor
protocol RideRecordingAccessing: AnyObject {
   var canBeginRide: Bool { get }
}
