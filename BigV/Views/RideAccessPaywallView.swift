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

   private let privacyURL = URL(string: "https://bigvelo.app/privacy")!
   private let termsURL = URL(string: "https://bigvelo.app/terms")!

   var body: some View {
      NavigationStack {
         ScrollView {
            VStack(alignment: .leading, spacing: 16) {
               Text(plusStore.accessHeadline)
                  .font(.title2.weight(.bold))
                  .foregroundStyle(.white)

               Text(plusStore.accessDetail)
                  .font(.body)
                  .foregroundStyle(.white.opacity(0.78))

               RidePlusPricingCard(plusStore: plusStore, accessibilityPrefix: "paywall")

               HStack(spacing: 16) {
                  Button("Restore") {
                     Task { await plusStore.restore() }
                  }
                  Button("Redeem Code") {
                     isShowingRedeem = true
                  }
                  Button("Privacy") { openURL(privacyURL) }
                  Button("Terms") { openURL(termsURL) }
               }
               .font(.caption.weight(.semibold))
               .foregroundStyle(.white.opacity(0.7))
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
         .task { await plusStore.loadProducts() }
         .onChange(of: plusStore.isPlus) { _, isPlus in
            if isPlus { onDismiss() }
         }
      }
      .preferredColorScheme(.dark)
   }
}
