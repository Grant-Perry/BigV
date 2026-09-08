//
//  RideAccessPaywallView.swift
//  BigV
//

import StoreKit
import SwiftUI

/// Shown when the 30-day trial has ended and the rider tries to start again.
struct RideAccessPaywallView: View {

   @Bindable var plusStore: BigVeloPlusStore
   var onDismiss: () -> Void

   @Environment(\.openURL) private var openURL
   @State private var isShowingRedeem = false
   @State private var isShowingManageSubscriptions = false

   var body: some View {
      NavigationStack {
         ScrollView {
            VStack(alignment: .leading, spacing: 16) {
               RideWordmark(pointSize: 34)

               Text(plusStore.accessHeadline)
                  .font(.title2.weight(.bold))
                  .foregroundStyle(RideDashboardTheme.ink)

               Text(plusStore.accessDetail)
                  .font(.body)
                  .foregroundStyle(RideDashboardTheme.ink(0.78))

               RidePlusPricingCard(plusStore: plusStore, accessibilityPrefix: "paywall")

               VStack(alignment: .leading, spacing: 8) {
                  HStack(spacing: 16) {
                     Button("Restore") {
                        Task { await plusStore.restore() }
                     }
                     Button("Redeem Code") {
                        isShowingRedeem = true
                     }
                     Button("Manage") {
                        isShowingManageSubscriptions = true
                     }
                  }
                  HStack(spacing: 16) {
                     Button("Privacy") { openURL(AppConstants.privacyURL) }
                     Button("Terms") { openURL(AppConstants.termsURL) }
                     Button("Support") { openURL(AppConstants.supportURL) }
                  }
               }
               .font(.caption.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ink(0.7))
            }
            .padding(20)
         }
         .scrollIndicators(.hidden)
         .background {
            RideAtmosphereBackground()
               .ignoresSafeArea()
         }
         .navigationTitle("Keep BigVelo")
         .navigationBarTitleDisplayMode(.inline)
         .toolbar {
            ToolbarItem(placement: .cancellationAction) {
               Button("Close", action: onDismiss)
            }
         }
         .offerCodeRedemption(isPresented: $isShowingRedeem) { _ in
            Task { await plusStore.refreshEntitlement() }
         }
         .manageSubscriptionsSheet(isPresented: $isShowingManageSubscriptions)
         .task { await plusStore.loadProducts() }
         .onChange(of: plusStore.isPlus) { _, isPlus in
            if isPlus { onDismiss() }
         }
      }
      .rideAppearance()
   }
}
