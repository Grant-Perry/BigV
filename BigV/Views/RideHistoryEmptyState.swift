//
//  RideHistoryEmptyState.swift
//  BigV
//

import SwiftUI

/// First-open garage: still expensive when there is nothing to show.
struct RideHistoryEmptyState: View {

   var body: some View {
      VStack(spacing: 22) {
         ZStack {
            Circle()
               .fill(
                  RadialGradient(
                     colors: [
                        RideDashboardTheme.ember.opacity(0.28),
                        RideDashboardTheme.ice.opacity(0.08),
                        .clear
                     ],
                     center: .center,
                     startRadius: 6,
                     endRadius: 90
                  )
               )
               .frame(width: 180, height: 180)

            Image(systemName: .bicycleIcon)
               .font(.system(size: 46, weight: .light))
               .foregroundStyle(.white.opacity(0.88))
         }

         VStack(spacing: 8) {
            Text("The garage is empty")
               .font(.title2.weight(.semibold))
               .foregroundStyle(.white)

            Text("Finish a ride. It lands here as the first wall.")
               .font(.subheadline)
               .foregroundStyle(.white.opacity(0.5))
               .multilineTextAlignment(.center)
         }
      }
      .padding(.horizontal, 32)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
   }
}

private extension String {
   static let bicycleIcon = "bicycle"
}
