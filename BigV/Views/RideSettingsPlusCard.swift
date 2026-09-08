//
//  RideSettingsPlusCard.swift
//  BigV
//

import StoreKit
import SwiftUI

/// The BigVelo section of Settings: what the rider has, what it costs, and the
/// three doors App Review requires — restore, redeem and manage.
///
/// Its own view because it owns two system sheets and the purchase surface, and
/// Settings should not carry that weight to lay out a units row.
struct RideSettingsPlusCard: View {

   @Bindable var plusStore: BigVeloPlusStore

   @Environment(\.openURL) private var openURL
   @State private var isShowingRedeem = false
   @State private var isShowingManageSubscriptions = false

   var body: some View {
      RideSettingsCard {
         RideWordmark(pointSize: 22)

         statusRow

         if let fraction = plusStore.trialFractionRemaining {
            trialMeter(fraction: fraction)
         }

         Text(plusStore.accessDetail)
            .font(.caption2)
            .foregroundStyle(RideDashboardTheme.ink(0.5))
            .fixedSize(horizontal: false, vertical: true)

         if !plusStore.isPlus {
            RidePlusPricingCard(plusStore: plusStore, accessibilityPrefix: "settings")
         }

         RideSettingsDivider()

         accountActions

         #if DEBUG
         Toggle("Force Plus (Debug)", isOn: $plusStore.forcePlusInDebug)
            .font(.caption)
            .foregroundStyle(RideDashboardTheme.ink(0.7))
            .tint(RideDashboardTheme.ember)
         #endif

         legalLinks

         if let message = plusStore.lastErrorMessage {
            Text(message)
               .font(.caption2)
               .foregroundStyle(RideDashboardTheme.halt)
         }
      }
      .offerCodeRedemption(isPresented: $isShowingRedeem) { _ in
         Task { await plusStore.refreshEntitlement() }
      }
      .manageSubscriptionsSheet(isPresented: $isShowingManageSubscriptions)
      .task {
         await plusStore.loadProducts()
      }
   }

   // MARK: - Status

   private var statusRow: some View {
      HStack(spacing: 8) {
         Text(plusStore.accessHeadline)
            .font(.headline)
            .foregroundStyle(statusTint)

         Spacer(minLength: 8)

         if plusStore.isPlus {
            Image(systemName: "checkmark.seal.fill")
               .font(.headline)
               .foregroundStyle(RideDashboardTheme.go)
         }
      }
   }

   private var statusTint: Color {
      switch plusStore.accessStatus {
         case .subscribed: RideDashboardTheme.go
         case .trial: RideDashboardTheme.ink
         case .expired: RideDashboardTheme.halt
      }
   }

   /// The free month as a bar rather than a sentence. A rider can read "eight
   /// days" and still not feel it; a meter three-quarters spent is immediate.
   private func trialMeter(fraction: Double) -> some View {
      Capsule(style: .continuous)
         .fill(RideDashboardTheme.ink(0.10))
         .frame(height: 5)
         .overlay(alignment: .leading) {
            GeometryReader { proxy in
               Capsule(style: .continuous)
                  .fill(fraction > 0.25 ? RideDashboardTheme.ice : RideDashboardTheme.ember)
                  .frame(width: max(5, proxy.size.width * fraction))
            }
         }
         .accessibilityElement()
         .accessibilityLabel("Trial remaining")
         .accessibilityValue(plusStore.accessHeadline)
   }

   // MARK: - Account

   private var accountActions: some View {
      HStack(spacing: 8) {
         Button("Restore") {
            Task { await plusStore.restore() }
         }
         .accessibilityIdentifier("settings.button.restorePurchases")

         Button("Redeem") {
            isShowingRedeem = true
         }
         .accessibilityIdentifier("settings.button.redeemCode")

         Button("Manage") {
            isShowingManageSubscriptions = true
         }
         .accessibilityIdentifier("settings.button.manageSubscriptions")

         Spacer(minLength: 0)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .font(.caption.weight(.semibold))
      .tint(RideDashboardTheme.ice)
   }

   /// Guideline 3.1.2 wants these on the surface that sells the subscription,
   /// so they stay in this card rather than moving to a footer of their own.
   private var legalLinks: some View {
      HStack(spacing: 14) {
         Button("Privacy") { openURL(AppConstants.privacyURL) }
         Button("Terms") { openURL(AppConstants.termsURL) }
         Button("Support") { openURL(AppConstants.supportURL) }

         Spacer(minLength: 0)
      }
      .buttonStyle(.plain)
      .font(.caption2.weight(.semibold))
      .foregroundStyle(RideDashboardTheme.ink(0.5))
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()

      RideSettingsPlusCard(plusStore: BigVeloPlusStore())
         .padding(16)
   }
   .preferredColorScheme(.dark)
}
