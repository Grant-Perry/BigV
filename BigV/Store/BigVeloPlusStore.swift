//
//  BigVeloPlusStore.swift
//  BigV
//

import Foundation
import StoreKit

/// StoreKit 2 entitlement for BigVelo.
///
/// Thirty days from first launch are the whole product. After that, `canBeginRide`
/// is false unless this Apple ID owns monthly, yearly or lifetime. History, saved
/// routes and export never read this store.
@Observable
@MainActor
final class BigVeloPlusStore: RideRecordingAccessing {

   // MARK: - Products

   private(set) var products: [Product] = []
   private(set) var monthlyProduct: Product?
   private(set) var yearlyProduct: Product?
   private(set) var lifetimeProduct: Product?

   // MARK: - Entitlement

   /// True when an active subscription or the lifetime non-consumable is owned.
   private(set) var isPlus = false

   /// First launch on this device. Resetting onboarding does not move this clock.
   private(set) var trialBeganAt: Date

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

   // MARK: - Access

   var accessStatus: RideAccessPolicy.Status {
      RideAccessPolicy.status(trialBeganAt: trialBeganAt, isSubscribed: isPlus)
   }

   var canBeginRide: Bool {
      RideAccessPolicy.canBeginRide(accessStatus)
   }

   var accessHeadline: String {
      switch accessStatus {
         case .subscribed:
            return "Unlocked"
         case .trial(let days):
            return days == 1 ? "1 day left" : "\(days) days left"
         case .expired:
            return "Trial ended"
      }
   }

   /// How much of the free month is still on the clock, `0...1`, or `nil` once
   /// there is no clock to show. Settings draws it as a meter so the rider sees
   /// the trial burning down instead of reading a number and guessing.
   var trialFractionRemaining: Double? {
      guard case .trial(let days) = accessStatus else { return nil }
      let total = RideAccessPolicy.trialLength / 86_400
      return min(1, max(0, Double(days) / total))
   }

   var accessDetail: String {
      switch accessStatus {
         case .subscribed:
            return "The full cockpit stays on — radar, Watch heart rate, record, history and export."
         case .trial:
            return "Thirty days, nothing held back. After that, recording and live sensors stop unless you keep BigVelo. Past rides stay here to view and export."
         case .expired:
            return "Recording, live radar and Watch start are off. Open past rides, saved routes and export. Keep BigVelo to ride again."
      }
   }

   // MARK: - Private

   @ObservationIgnored private var updatesTask: Task<Void, Never>?
   @ObservationIgnored private let defaults: UserDefaults

   private enum Key {
      static let trialBeganAt = "ride.access.trialBeganAt"
      static let isPlus = "ride.access.isPlus"
   }

   /// Back-off between launch re-checks when StoreKit answered with nothing.
   /// A cold `storekitd` or a sandbox session that needs re-auth usually
   /// settles within the first pass or two.
   private static let silentRetryDelays: [Duration] = [.seconds(3), .seconds(10), .seconds(30)]

   // MARK: - Lifecycle

   /// The entitlement is answered synchronously from the last verified result
   /// and then re-verified against StoreKit's local receipt straight away.
   ///
   /// Neither waits on the product catalog. A START from the wrist can arrive
   /// in the first second of a background launch, with no signal, long before
   /// `Product.products(for:)` returns — and a rider whose trial has lapsed but
   /// who owns Plus must not be refused while the catalog loads.
   init(defaults: UserDefaults = .standard) {
      self.defaults = defaults
      if let stored = defaults.object(forKey: Key.trialBeganAt) as? Date {
         trialBeganAt = stored
      } else {
         trialBeganAt = .now
         defaults.set(trialBeganAt, forKey: Key.trialBeganAt)
      }

      isPlus = defaults.bool(forKey: Key.isPlus)

      updatesTask = Task { [weak self] in
         await self?.refreshEntitlementAtLaunch()

         for await update in Transaction.updates {
            await self?.handle(update)
         }
      }
   }

   deinit {
      updatesTask?.cancel()
   }

   // MARK: - Catalog

   /// Fetches the catalog, then re-checks the entitlement either way: the
   /// catalog needs the network, the receipt does not, and a failed fetch must
   /// never leave a paying rider locked out.
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
      } catch {
         lastErrorMessage = error.localizedDescription
         DebugPrint(mode: .persistence, "StoreKit product load failed: \(error.localizedDescription)")
      }

      await refreshEntitlement()
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
               // The signed transaction in hand is the proof. Apply it before the
               // receipt re-read so a slow or silent StoreKit can never leave a
               // rider who just paid staring at the paywall.
               apply(PlusEntitlementResolver.verdict(evidence: [evidence(from: transaction)]), authoritative: false)
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
         // Apple just re-sent the receipt on request, so this pass is allowed
         // to say "nothing owned" — the only pass that is.
         await refreshEntitlement(authoritative: true)
         DebugPrint(mode: .persistence, "StoreKit restore finished, isPlus=\(isPlus)")
      } catch {
         lastErrorMessage = error.localizedDescription
         DebugPrint(mode: .persistence, "StoreKit restore failed: \(error.localizedDescription)")
      }
   }

   // MARK: - Entitlements

   /// Re-reads the local receipt and applies the verdict.
   ///
   /// Reads two views of the same receipt: `currentEntitlements` for what is
   /// active now, and `latest(for:)` per product so a subscription that has
   /// run out still counts as evidence. Without the second read a lapsed
   /// yearly and an empty daemon look the same, and the store would either
   /// lock out a paying rider or wave through a lapsed one.
   ///
   /// - Parameter authoritative: Pass `true` only after `AppStore.sync()`. On
   ///   every other pass an empty answer leaves the remembered value alone.
   @discardableResult
   func refreshEntitlement(authoritative: Bool = false) async -> PlusEntitlementResolver.Verdict {
      var evidence: [PlusEntitlementResolver.Evidence] = []

      for await result in Transaction.currentEntitlements {
         guard let transaction = try? checkVerified(result) else { continue }
         evidence.append(self.evidence(from: transaction))
      }

      for productID in BigVeloPlusProductID.allCases {
         guard let result = await Transaction.latest(for: productID.rawValue),
               let transaction = try? checkVerified(result) else { continue }
         evidence.append(self.evidence(from: transaction))
      }

      let verdict = PlusEntitlementResolver.verdict(evidence: evidence)
      apply(verdict, authoritative: authoritative)
      DebugPrint(mode: .persistence, "StoreKit entitlement verdict=\(verdict) isPlus=\(isPlus)")
      return verdict
   }

   /// First pass after launch, with a short back-off while StoreKit is silent.
   /// Stops on the first real answer, or after the last retry, whichever comes
   /// first; a rider with nothing to restore costs three cheap receipt reads.
   private func refreshEntitlementAtLaunch() async {
      var verdict = await refreshEntitlement()
      for delay in Self.silentRetryDelays where verdict == .noEvidence {
         try? await Task.sleep(for: delay)
         guard !Task.isCancelled else { return }
         verdict = await refreshEntitlement()
      }
   }

   private func apply(_ verdict: PlusEntitlementResolver.Verdict, authoritative: Bool) {
      let cached = defaults.bool(forKey: Key.isPlus)
      let owned = PlusEntitlementResolver.isPlus(after: verdict, cached: cached, authoritative: authoritative)

      // Remembered so the next launch answers correctly before this runs.
      defaults.set(owned, forKey: Key.isPlus)

      #if DEBUG
      isPlus = owned || forcePlusInDebug
      #else
      isPlus = owned
      #endif
   }

   private func evidence(from transaction: Transaction) -> PlusEntitlementResolver.Evidence {
      PlusEntitlementResolver.Evidence(
         productID: transaction.productID,
         expirationDate: transaction.expirationDate,
         revocationDate: transaction.revocationDate
      )
   }

   private func refreshEntitlement() {
      Task { await refreshEntitlement() }
   }

   // MARK: - Display Helpers

   /// Shown instead of a made-up price when the catalog failed to load.
   static let priceUnavailable = "Price unavailable"

   /// True once the catalog has loaded; false after a failed or empty fetch.
   var hasProducts: Bool {
      monthlyProduct != nil || yearlyProduct != nil || lifetimeProduct != nil
   }

   func displayPrice(for productID: BigVeloPlusProductID) -> String {
      switch productID {
         case .monthly:
            return monthlyProduct?.displayPrice ?? Self.priceUnavailable
         case .yearly:
            return yearlyProduct?.displayPrice ?? Self.priceUnavailable
         case .lifetime:
            return lifetimeProduct?.displayPrice ?? Self.priceUnavailable
      }
   }

   var yearlyDetail: String {
      guard yearlyProduct != nil else { return Self.priceUnavailable }
      return "\(displayPrice(for: .yearly))/yr"
   }

   var monthlyDetail: String {
      guard monthlyProduct != nil else { return Self.priceUnavailable }
      return "\(displayPrice(for: .monthly))/mo"
   }

   var lifetimeDetail: String {
      guard lifetimeProduct != nil else { return Self.priceUnavailable }
      return "\(displayPrice(for: .lifetime)) once"
   }

   // MARK: - Private

   private func handle(_ result: VerificationResult<Transaction>) async {
      do {
         let transaction = try checkVerified(result)
         await transaction.finish()
         // A renewal or Ask-to-Buy approval is proof on its own. A refund of
         // one product is not proof the rider owns nothing else, so a lapse
         // waits for the full read below.
         if PlusEntitlementResolver.verdict(evidence: [evidence(from: transaction)]) == .owned {
            apply(.owned, authoritative: false)
         }
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
