//
//  BigVeloPlusStoreTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

/// The entitlement has to be right the instant the store exists. A START from
/// the wrist can land before any StoreKit round-trip completes, and a rider
/// whose free month has lapsed but who owns Plus was being refused in that gap.
@MainActor
struct BigVeloPlusStoreTests {

   private func makeDefaults() throws -> UserDefaults {
      let suite = "BigVeloPlusStoreTests.\(UUID().uuidString)"
      let defaults = try #require(UserDefaults(suiteName: suite))
      defaults.removePersistentDomain(forName: suite)
      return defaults
   }

   @Test func aRememberedEntitlementUnlocksRecordingBeforeStoreKitAnswers() throws {
      let defaults = try makeDefaults()
      let lapsed = Date.now.addingTimeInterval(-RideAccessPolicy.trialLength * 2)
      defaults.set(lapsed, forKey: "ride.access.trialBeganAt")
      defaults.set(true, forKey: "ride.access.isPlus")

      let store = BigVeloPlusStore(defaults: defaults)

      #expect(store.isPlus)
      #expect(store.accessStatus == .subscribed)
      #expect(store.canBeginRide)
   }

   @Test func aLapsedTrialWithNothingRememberedStaysLocked() throws {
      let defaults = try makeDefaults()
      let lapsed = Date.now.addingTimeInterval(-RideAccessPolicy.trialLength * 2)
      defaults.set(lapsed, forKey: "ride.access.trialBeganAt")

      let store = BigVeloPlusStore(defaults: defaults)

      #expect(!store.isPlus)
      #expect(store.accessStatus == .expired)
      #expect(!store.canBeginRide)
   }
}
