//
//  PlusEntitlementResolver.swift
//  BigV
//

import Foundation

/// Turns what StoreKit said into a yes / no / "it said nothing".
///
/// `Transaction.currentEntitlements` yields only *active* transactions, so a
/// lapsed subscriber and a cold `storekitd` that has not loaded the receipt yet
/// both look identical: an empty stream. The store must never treat that
/// silence as a refund. This resolver separates the two by also reading
/// `Transaction.latest(for:)`, which still names an expired subscription, and
/// returns `.noEvidence` only when StoreKit named nothing of ours at all.
nonisolated enum PlusEntitlementResolver {

   // MARK: - Evidence

   /// The three fields of a transaction the verdict depends on.
   struct Evidence: Equatable, Sendable {
      let productID: String
      let expirationDate: Date?
      let revocationDate: Date?

      init(productID: String, expirationDate: Date? = nil, revocationDate: Date? = nil) {
         self.productID = productID
         self.expirationDate = expirationDate
         self.revocationDate = revocationDate
      }

      func isActive(now: Date) -> Bool {
         if revocationDate != nil { return false }
         if let expirationDate, expirationDate <= now { return false }
         return true
      }
   }

   // MARK: - Verdict

   enum Verdict: Equatable, Sendable {
      /// At least one of our products is owned and active.
      case owned
      /// StoreKit named our products and every one is expired or revoked.
      case lapsed
      /// StoreKit named nothing of ours. Offline, cold daemon, or a rider who
      /// never bought anything — indistinguishable here.
      case noEvidence
   }

   static func verdict(evidence: [Evidence], now: Date = .now) -> Verdict {
      let ours = evidence.filter { BigVeloPlusProductID(rawValue: $0.productID) != nil }
      guard !ours.isEmpty else { return .noEvidence }
      return ours.contains { $0.isActive(now: now) } ? .owned : .lapsed
   }

   // MARK: - Decision

   /// `authoritative` is true after `AppStore.sync()`: the rider asked for a
   /// restore and Apple answered, so an empty answer is the answer. Every other
   /// pass keeps the remembered value when StoreKit is silent.
   static func isPlus(after verdict: Verdict, cached: Bool, authoritative: Bool) -> Bool {
      switch verdict {
         case .owned: true
         case .lapsed: false
         case .noEvidence: authoritative ? false : cached
      }
   }
}
