//
//  BigVeloPlusStore.swift
//  BigV
//

import Foundation
import StoreKit

/// StoreKit 2 entitlement for BigVelo+.
///
/// Radar, Watch HR, record, History and Health never read `isPlus`. This store
/// only unlocks future Plus surfaces (nav-depth weather and similar).
@Observable
@MainActor
final class BigVeloPlusStore {

   // MARK: - Products

   private(set) var products: [Product] = []
   private(set) var monthlyProduct: Product?
   private(set) var yearlyProduct: Product?
   private(set) var lifetimeProduct: Product?

   // MARK: - Entitlement

   /// True when an active subscription or the lifetime non-consumable is owned.
   private(set) var isPlus = false

   private(set) var isLoadingProducts = false
   private(set) var isPurchasing = false
   private(set) var lastErrorMessage: String?

   #if DEBUG
   /// Debug-only escape hatch so daily Xcode rides never need a fake purchase.
   /// Never compiled into Release / Archive.
   var forcePlusInDebug = false {
      didSet { refreshEntitlement() }
   }
   #endif

   // MARK: - Private

   @ObservationIgnored private var updatesTask: Task<Void, Never>?

   // MARK: - Lifecycle

   init() {
      updatesTask = Task { [weak self] in
         for await update in Transaction.updates {
            await self?.handle(update)
         }
      }
   }

   deinit {
      updatesTask?.cancel()
   }

   // MARK: - Catalog

   func loadProducts() async {
      guard !isLoadingProducts else { return }
      isLoadingProducts = true
      lastErrorMessage = nil
      defer { isLoadingProducts = false }

      do {
         let ids = BigVeloPlusProductID.allCases.map(\.rawValue)
         let loaded = try await Product.products(for: ids)
         products = loaded.sorted { $0.price < $1.price }
         monthlyProduct = loaded.first { $0.id == BigVeloPlusProductID.monthly.rawValue }
         yearlyProduct = loaded.first { $0.id == BigVeloPlusProductID.yearly.rawValue }
         lifetimeProduct = loaded.first { $0.id == BigVeloPlusProductID.lifetime.rawValue }
         DebugPrint(mode: .persistence, "StoreKit loaded \(loaded.count) Plus products")
         await refreshEntitlement()
      } catch {
         lastErrorMessage = error.localizedDescription
         DebugPrint(mode: .persistence, "StoreKit product load failed: \(error.localizedDescription)")
      }
   }

   // MARK: - Purchase

   @discardableResult
   func purchase(_ product: Product) async -> Bool {
      guard !isPurchasing else { return false }
      isPurchasing = true
      lastErrorMessage = nil
      defer { isPurchasing = false }

      do {
         let result = try await product.purchase()
         switch result {
            case .success(let verification):
               let transaction = try checkVerified(verification)
               await transaction.finish()
               await refreshEntitlement()
               DebugPrint(mode: .persistence, "StoreKit purchase ok: \(product.id)")
               return true

            case .userCancelled:
               return false

            case .pending:
               lastErrorMessage = "Purchase is pending approval."
               return false

            @unknown default:
               return false
         }
      } catch {
         lastErrorMessage = error.localizedDescription
         DebugPrint(mode: .persistence, "StoreKit purchase failed: \(error.localizedDescription)")
         return false
      }
   }

   func restore() async {
      lastErrorMessage = nil
      do {
         try await AppStore.sync()
         await refreshEntitlement()
         DebugPrint(mode: .persistence, "StoreKit restore finished, isPlus=\(isPlus)")
      } catch {
         lastErrorMessage = error.localizedDescription
         DebugPrint(mode: .persistence, "StoreKit restore failed: \(error.localizedDescription)")
      }
   }

   // MARK: - Entitlements

   func refreshEntitlement() async {
      var owned = false

      for await result in Transaction.currentEntitlements {
         guard let transaction = try? checkVerified(result) else { continue }
         guard BigVeloPlusProductID(rawValue: transaction.productID) != nil else { continue }

         if transaction.revocationDate != nil { continue }
         if let expiration = transaction.expirationDate, expiration < Date() { continue }

         owned = true
         break
      }

      #if DEBUG
      isPlus = owned || forcePlusInDebug
      #else
      isPlus = owned
      #endif
   }

   private func refreshEntitlement() {
      Task { await refreshEntitlement() }
   }

   // MARK: - Display Helpers

   func displayPrice(for productID: BigVeloPlusProductID) -> String {
      switch productID {
         case .monthly:
            return monthlyProduct?.displayPrice ?? "$4.99"
         case .yearly:
            return yearlyProduct?.displayPrice ?? "$29.99"
         case .lifetime:
            return lifetimeProduct?.displayPrice ?? "$79"
      }
   }

   var yearlyHasFreeTrial: Bool {
      guard let offer = yearlyProduct?.subscription?.introductoryOffer else { return true }
      return offer.paymentMode == .freeTrial
   }

   // MARK: - Private

   private func handle(_ result: VerificationResult<Transaction>) async {
      do {
         let transaction = try checkVerified(result)
         await transaction.finish()
         await refreshEntitlement()
      } catch {
         DebugPrint(mode: .persistence, "StoreKit update verify failed: \(error.localizedDescription)")
      }
   }

   private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
      switch result {
         case .unverified(_, let error):
            throw error
         case .verified(let value):
            return value
      }
   }
}
