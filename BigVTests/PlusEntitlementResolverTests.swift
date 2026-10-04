//
//  PlusEntitlementResolverTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

struct PlusEntitlementResolverTests {

   private typealias Evidence = PlusEntitlementResolver.Evidence
   private typealias Verdict = PlusEntitlementResolver.Verdict

   private let now = Date(timeIntervalSince1970: 1_700_000_000)
   private let lifetime = BigVeloPlusProductID.lifetime.rawValue
   private let yearly = BigVeloPlusProductID.yearly.rawValue

   // MARK: - Verdict

   @Test func lifetimeIsOwned() {
      let verdict = PlusEntitlementResolver.verdict(evidence: [Evidence(productID: lifetime)], now: now)
      #expect(verdict == .owned)
   }

   @Test func anActiveSubscriptionIsOwned() {
      let evidence = [Evidence(productID: yearly, expirationDate: now.addingTimeInterval(86_400))]
      #expect(PlusEntitlementResolver.verdict(evidence: evidence, now: now) == .owned)
   }

   @Test func anExpiredSubscriptionIsLapsedNotSilent() {
      let evidence = [Evidence(productID: yearly, expirationDate: now.addingTimeInterval(-60))]
      #expect(PlusEntitlementResolver.verdict(evidence: evidence, now: now) == .lapsed)
   }

   @Test func aRefundedLifetimeIsLapsed() {
      let evidence = [Evidence(productID: lifetime, revocationDate: now.addingTimeInterval(-60))]
      #expect(PlusEntitlementResolver.verdict(evidence: evidence, now: now) == .lapsed)
   }

   @Test func anExpiredSubscriptionNextToLifetimeIsStillOwned() {
      let evidence = [
         Evidence(productID: yearly, expirationDate: now.addingTimeInterval(-60)),
         Evidence(productID: lifetime)
      ]
      #expect(PlusEntitlementResolver.verdict(evidence: evidence, now: now) == .owned)
   }

   @Test func anEmptyStreamIsNoEvidence() {
      #expect(PlusEntitlementResolver.verdict(evidence: [], now: now) == .noEvidence)
   }

   @Test func someoneElsesProductIsNoEvidence() {
      let evidence = [Evidence(productID: "com.other.app.pro")]
      #expect(PlusEntitlementResolver.verdict(evidence: evidence, now: now) == .noEvidence)
   }

   // MARK: - Decision

   @Test func silenceKeepsAPayingRiderUnlocked() {
      #expect(PlusEntitlementResolver.isPlus(after: .noEvidence, cached: true, authoritative: false))
   }

   @Test func silenceKeepsANewRiderLocked() {
      #expect(PlusEntitlementResolver.isPlus(after: .noEvidence, cached: false, authoritative: false) == false)
   }

   @Test func aRestoreThatFindsNothingLocks() {
      #expect(PlusEntitlementResolver.isPlus(after: .noEvidence, cached: true, authoritative: true) == false)
   }

   @Test func aLapseAlwaysLocks() {
      #expect(PlusEntitlementResolver.isPlus(after: .lapsed, cached: true, authoritative: false) == false)
   }

   @Test func ownershipAlwaysUnlocks() {
      #expect(PlusEntitlementResolver.isPlus(after: .owned, cached: false, authoritative: false))
      #expect(PlusEntitlementResolver.isPlus(after: .owned, cached: false, authoritative: true))
   }
}
