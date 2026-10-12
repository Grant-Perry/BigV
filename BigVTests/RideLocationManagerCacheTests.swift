//
//  RideLocationManagerCacheTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

/// The cached-fix rule: what the manager drops as a Core Location replay and
/// what it must deliver no matter how long it sat in the main-actor queue.
struct RideLocationManagerCacheTests {

   private let started = Date(timeIntervalSince1970: 1_000_000)

   @Test func aFixStampedBeforeTheReceiverStartedIsCached() {
      #expect(
         RideLocationManager.isReplayedFromCache(
            started.addingTimeInterval(-30),
            deliveryStartedAt: started
         )
      )
   }

   @Test func aFixStampedABreathBeforeTheStartIsStillLive() {
      #expect(
         !RideLocationManager.isReplayedFromCache(
            started.addingTimeInterval(-0.5),
            deliveryStartedAt: started
         )
      )
   }

   /// A busy main actor can hold a live fix for longer than any age cutoff.
   /// It is still the newest position there is, and must reach the engine.
   @Test func aLiveFixDelayedOnTheMainActorIsNotCached() {
      #expect(
         !RideLocationManager.isReplayedFromCache(
            started.addingTimeInterval(5),
            deliveryStartedAt: started
         )
      )
   }

   @Test func withNoReceiverStartNothingIsTreatedAsCached() {
      #expect(
         !RideLocationManager.isReplayedFromCache(
            started.addingTimeInterval(-3_600),
            deliveryStartedAt: nil
         )
      )
   }
}
