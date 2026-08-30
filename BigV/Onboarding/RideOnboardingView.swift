//
//  RideOnboardingView.swift
//  BigV
//

import StoreKit
import SwiftUI
import UIKit

/// Four-page first-launch pager. Page 4 is StoreKit; never a hard lock.
struct RideOnboardingView: View {

   @Bindable var plusStore: BigVeloPlusStore
   var onFinished: () -> Void

   @Environment(\.accessibilityReduceMotion) private var reduceMotion
   @Environment(\.openURL) private var openURL

   @State private var page: RideOnboardingPageID = .kit
   @State private var isShowingRedeem = false

   private let privacyURL = URL(string: "https://bigvelo.app/privacy")!
   private let termsURL = URL(string: "https://bigvelo.app/terms")!

   var body: some View {
      ZStack {
         RideDashboardTheme.void.ignoresSafeArea()

         TabView(selection: $page) {
            ForEach(RideOnboardingPageID.allCases) { pageID in
               pageChrome(for: pageID)
                  .tag(pageID)
            }
         }
         .tabViewStyle(.page(indexDisplayMode: .never))
         .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: page)

         VStack {
            topBar
            Spacer()
            bottomBar
         }
         .padding(.horizontal, 16)
         .padding(.top, 8)
         .padding(.bottom, 12)
      }
      .preferredColorScheme(.dark)
      .offerCodeRedemption(isPresented: $isShowingRedeem) { _ in
         Task { await plusStore.refreshEntitlement() }
      }
      .task {
         await plusStore.loadProducts()
      }
   }

   // MARK: - Chrome

   private var topBar: some View {
      HStack {
         pageDots
         Spacer()
         Button("Skip") {
            finish()
         }
         .font(.subheadline.weight(.semibold))
         .foregroundStyle(.white.opacity(0.72))
         .accessibilityIdentifier("onboarding.button.skip")
      }
   }

   private var pageDots: some View {
      HStack(spacing: 6) {
         ForEach(RideOnboardingPageID.allCases) { pageID in
            Capsule()
               .fill(pageID == page ? RideDashboardTheme.ice : .white.opacity(0.28))
               .frame(width: pageID == page ? 18 : 6, height: 6)
         }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Page \(page.rawValue + 1) of \(RideOnboardingPageID.allCases.count)")
   }

   private var bottomBar: some View {
      VStack(spacing: 10) {
         if page == .plus {
            plusActions
         }

         Button(page == .plus ? "Start Riding" : "Continue") {
            if page == .plus {
               finish()
            } else if let next = RideOnboardingPageID(rawValue: page.rawValue + 1) {
               page = next
            }
         }
         .buttonStyle(.borderedProminent)
         .controlSize(.extraLarge)
         .tint(RideDashboardTheme.go)
         .font(.headline)
         .frame(maxWidth: .infinity)
         .accessibilityIdentifier(page == .plus ? "onboarding.button.start" : "onboarding.button.continue")
      }
   }

   // MARK: - Pages

   private func pageChrome(for pageID: RideOnboardingPageID) -> some View {
      ZStack(alignment: .bottom) {
         plate(for: pageID)

         VStack(alignment: .leading, spacing: 12) {
            Text(pageID.title)
               .font(.title.weight(.bold))
               .foregroundStyle(.white)

            Text(pageID.body)
               .font(.body)
               .foregroundStyle(.white.opacity(0.82))
               .fixedSize(horizontal: false, vertical: true)

            if pageID == .plus {
               plusPricingCard
            }
         }
         .padding(18)
         .frame(maxWidth: .infinity, alignment: .leading)
         .rideGlassCard(density: .standard, cornerRadius: 22)
         .padding(.horizontal, 16)
         .padding(.bottom, 100)
      }
   }

   @ViewBuilder
   private func plate(for pageID: RideOnboardingPageID) -> some View {
      Group {
         if UIImage(named: pageID.plateName) != nil {
            Image(pageID.plateName)
               .resizable()
               .scaledToFill()
         } else {
            Image(RideOnboardingArt.fallbackPlate(for: pageID))
               .resizable()
               .scaledToFill()
               .overlay(Color.black.opacity(0.25))
         }
      }
      .overlay {
         LinearGradient(
            colors: [
               RideDashboardTheme.void.opacity(0.35),
               RideDashboardTheme.void.opacity(0.15),
               RideDashboardTheme.void.opacity(0.88)
            ],
            startPoint: .top,
            endPoint: .bottom
         )
      }
      .ignoresSafeArea()
      .allowsHitTesting(false)
   }

   // MARK: - Plus

   private var plusPricingCard: some View {
      VStack(alignment: .leading, spacing: 10) {
         if plusStore.isPlus {
            Label("BigVelo+ is unlocked", systemImage: "checkmark.seal.fill")
               .font(.subheadline.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.go)
         }

         pricingRow(
            title: "Yearly",
            detail: plusStore.yearlyHasFreeTrial ? "7 days free, then \(plusStore.displayPrice(for: .yearly))/yr" : plusStore.displayPrice(for: .yearly) + "/yr",
            product: plusStore.yearlyProduct,
            emphasized: true
         )

         pricingRow(
            title: "Monthly",
            detail: "\(plusStore.displayPrice(for: .monthly))/mo",
            product: plusStore.monthlyProduct,
            emphasized: false
         )

         pricingRow(
            title: "Lifetime",
            detail: "\(plusStore.displayPrice(for: .lifetime)) once",
            product: plusStore.lifetimeProduct,
            emphasized: false
         )

         Text("Stays free: rear radar, Watch HR, record, History, Health.")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.55))

         if let message = plusStore.lastErrorMessage {
            Text(message)
               .font(.caption2)
               .foregroundStyle(RideDashboardTheme.halt)
         }
      }
      .padding(.top, 4)
   }

   private func pricingRow(
      title: String,
      detail: String,
      product: Product?,
      emphasized: Bool
   ) -> some View {
      Button {
         guard let product else { return }
         Task { await plusStore.purchase(product) }
      } label: {
         HStack {
            VStack(alignment: .leading, spacing: 2) {
               Text(title)
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(.white)
               Text(detail)
                  .font(.caption)
                  .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            if plusStore.isPurchasing {
               ProgressView()
                  .tint(.white)
            } else {
               Image(systemName: emphasized ? "sparkles" : "plus.circle")
                  .foregroundStyle(emphasized ? RideDashboardTheme.ember : RideDashboardTheme.ice)
            }
         }
         .padding(12)
         .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
               .fill(emphasized ? RideDashboardTheme.ember.opacity(0.18) : Color.white.opacity(0.06))
         )
         .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
               .strokeBorder(
                  emphasized ? RideDashboardTheme.ember.opacity(0.55) : Color.white.opacity(0.12),
                  lineWidth: 1
               )
         }
      }
      .buttonStyle(.plain)
      .disabled(product == nil || plusStore.isPurchasing || plusStore.isPlus)
      .accessibilityIdentifier("onboarding.plus.\(title.lowercased())")
   }

   private var plusActions: some View {
      HStack(spacing: 16) {
         Button("Restore") {
            Task { await plusStore.restore() }
         }
         Button("Redeem Code") {
            isShowingRedeem = true
         }
         Button("Privacy") {
            openURL(privacyURL)
         }
         Button("Terms") {
            openURL(termsURL)
         }
      }
      .font(.caption.weight(.semibold))
      .foregroundStyle(.white.opacity(0.7))
      .frame(maxWidth: .infinity)
   }

   // MARK: - Finish

   private func finish() {
      onFinished()
   }
}

#Preview {
   RideOnboardingView(plusStore: BigVeloPlusStore(), onFinished: {})
}
