//
//  ActiveRouteBannerView.swift
//  BigV
//

import SwiftUI

/// The live destination on the Ride To tab, with a way to drop it.
///
/// Search stays the primary action. This only names where they are already
/// going and makes Stop Route obvious, so they never hit END to change plans.
struct ActiveRouteBannerView: View {

   let destinationName: String
   let isRideActive: Bool
   let onStopRoute: () -> Void

   var body: some View {
      VStack(alignment: .leading, spacing: 10) {
         HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
               Text(destinationName)
                  .font(.subheadline.weight(.bold))
                  .foregroundStyle(RideDashboardTheme.ink)
                  .lineLimit(2)

               Text(statusCopy)
                  .font(.caption)
                  .foregroundStyle(RideDashboardTheme.ink(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Stop Route", action: onStopRoute)
               .font(.subheadline.weight(.bold))
               .buttonStyle(.bordered)
               .tint(RideDashboardTheme.ink(0.7))
               .accessibilityHint(stopHint)
               .accessibilityIdentifier("planner.banner.stopRoute")
         }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .rideGlassCard(density: .hud, cornerRadius: 16)
      .accessibilityIdentifier("planner.banner.activeRoute")
   }

   private var statusCopy: String {
      isRideActive
         ? "Stop this route without ending the ride."
         : "The line stays until you start, or stop it here."
   }

   private var stopHint: String {
      isRideActive
         ? "Clears the route and stops turn calls. The ride keeps recording."
         : "Clears the planned route."
   }
}

#Preview {
   ZStack {
      Color.black.ignoresSafeArea()
      ActiveRouteBannerView(
         destinationName: "Noland Trail",
         isRideActive: true,
         onStopRoute: {}
      )
      .padding()
   }
   .preferredColorScheme(.dark)
}
