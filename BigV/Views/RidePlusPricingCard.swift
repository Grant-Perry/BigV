//
//  RidePlusPricingCard.swift
//  BigV
//

import StoreKit
import SwiftUI

/// Monthly / yearly / lifetime rows shared by onboarding, Settings and the lock sheet.
struct RidePlusPricingCard: View {

   @Bindable var plusStore: BigVeloPlusStore
   var accessibilityPrefix: String = "plus"

   var body: some View {
      VStack(alignment: .leading, spacing: 10) {
         if plusStore.isPlus {
            Label("BigVelo is unlocked", systemImage: "checkmark.seal.fill")
               .font(.subheadline.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.go)
         }

         pricingRow(
            title: "Yearly",
            detail: plusStore.yearlyDetail,
            product: plusStore.yearlyProduct,
            emphasized: true
         )

         pricingRow(
            title: "Monthly",
            detail: plusStore.monthlyDetail,
            product: plusStore.monthlyProduct,
            emphasized: false
         )

         pricingRow(
            title: "Lifetime",
            detail: plusStore.lifetimeDetail,
            product: plusStore.lifetimeProduct,
            emphasized: false
         )

         if let message = plusStore.lastErrorMessage {
            Text(message)
               .font(.caption2)
               .foregroundStyle(RideDashboardTheme.halt)
         }
      }
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
                  .foregroundStyle(RideDashboardTheme.ink)
               Text(detail)
                  .font(.caption)
                  .foregroundStyle(RideDashboardTheme.ink(0.6))
            }
            Spacer()
            if plusStore.isPurchasing {
               ProgressView()
                  .tint(RideDashboardTheme.ink)
            } else {
               Image(systemName: emphasized ? "sparkles" : "plus.circle")
                  .foregroundStyle(emphasized ? RideDashboardTheme.ember : RideDashboardTheme.ice)
            }
         }
         .padding(12)
         .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
               .fill(emphasized ? RideDashboardTheme.ember.opacity(0.18) : RideDashboardTheme.ink(0.06))
         )
         .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
               .strokeBorder(
                  emphasized ? RideDashboardTheme.ember.opacity(0.55) : RideDashboardTheme.ink(0.12),
                  lineWidth: 1
               )
         }
      }
      .buttonStyle(.plain)
      .disabled(product == nil || plusStore.isPurchasing || plusStore.isPlus)
      .accessibilityIdentifier("\(accessibilityPrefix).plus.\(title.lowercased())")
   }
}
