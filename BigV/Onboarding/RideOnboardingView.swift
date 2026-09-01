//
//  RideOnboardingView.swift
//  BigV
//

import StoreKit
import SwiftUI
import UIKit

/// Four-page first-launch pager. Page 4 is the 30-day trial offer; never a hard lock.
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

         if page.showsGarminAffiliationNote {
            garminAffiliationFootnote
         }
      }
   }

   private var garminAffiliationFootnote: some View {
      Text("\(Text("*").baselineOffset(4)) BigVelo is not affiliated with Garmin.")
         .font(.caption2)
         .foregroundStyle(.white.opacity(0.55))
         .frame(maxWidth: .infinity)
         .accessibilityLabel("BigVelo is not affiliated with Garmin.")
   }

   // MARK: - Pages

   private func pageChrome(for pageID: RideOnboardingPageID) -> some View {
      ZStack(alignment: .bottom) {
         plate(for: pageID)

         VStack(alignment: .leading, spacing: 12) {
            Text(pageID.title)
               .font(.title.weight(.bold))
               .foregroundStyle(.white)

            if let lead = pageID.lead {
               markedVariaText(lead)
                  .font(.body.weight(.semibold))
                  .foregroundStyle(.white)
                  .fixedSize(horizontal: false, vertical: true)
            }

            markedVariaText(pageID.body)
               .font(.body)
               .foregroundStyle(.white.opacity(0.82))
               .fixedSize(horizontal: false, vertical: true)

            if !pageID.highlights.isEmpty {
               highlightList(pageID.highlights)
            }

            if pageID == .plus {
               plusPricingCard
            }
         }
         .padding(18)
         .frame(maxWidth: .infinity, alignment: .leading)
         .rideGlassCard(density: .standard, cornerRadius: 22)
         .padding(.horizontal, 16)
         .padding(.bottom, pageID.showsGarminAffiliationNote ? 128 : 100)
      }
   }

   /// Marks Varia™ with a superscript * without dropping the words in front of it.
   private func markedVariaText(_ copy: String) -> Text {
      guard let mark = copy.range(of: "Varia™") else { return Text(copy) }
      let prefix = String(copy[..<mark.lowerBound])
      let rest = String(copy[mark.upperBound...])
      return Text("\(prefix)Varia™\(Text("*").font(.footnote.weight(.bold)).baselineOffset(8))\(rest)")
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

   private func highlightList(_ highlights: [RideOnboardingHighlight]) -> some View {
      VStack(alignment: .leading, spacing: 8) {
         ForEach(highlights, id: \.self) { highlight in
            HStack(alignment: .firstTextBaseline, spacing: 10) {
               Image(systemName: highlight.symbol)
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(RideDashboardTheme.ice)
                  .frame(width: 22)

               Text(highlight.text)
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(.white.opacity(0.92))
            }
            .accessibilityElement(children: .combine)
         }
      }
      .padding(.top, 4)
   }

   // MARK: - Plus

   private var plusPricingCard: some View {
      RidePlusPricingCard(plusStore: plusStore, accessibilityPrefix: "onboarding")
         .padding(.top, 4)
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
