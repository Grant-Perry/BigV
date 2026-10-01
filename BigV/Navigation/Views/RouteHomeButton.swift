//
//  RouteHomeButton.swift
//  BigV
//

import SwiftUI

/// One tap toward home from the Ride To tab.
///
/// With a home set it plans the way there. Without one it opens the address
/// sheet, so the button teaches itself rather than sitting disabled.
struct RouteHomeButton: View {

   let homeLabel: String?
   let onRideHome: () -> Void
   let onSetHome: () -> Void

   private var hasHome: Bool { homeLabel != nil }

   var body: some View {
      Button(action: hasHome ? onRideHome : onSetHome) {
         HStack(spacing: 12) {
            Image(systemName: hasHome ? .homeIcon : .setHomeIcon)
               .font(.title3.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ember)
               .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
               Text(hasHome ? "Home" : "Set Home Address")
                  .font(.subheadline.weight(.bold))
                  .foregroundStyle(RideDashboardTheme.ink)

               Text(homeLabel ?? "One tap to plan the way back")
                  .font(.caption)
                  .foregroundStyle(RideDashboardTheme.ink(0.5))
                  .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: hasHome ? .goIcon : .chevronIcon)
               .font(.caption.weight(.bold))
               .foregroundStyle(hasHome ? RideDashboardTheme.ember : RideDashboardTheme.ink(0.3))
         }
         .padding(.horizontal, 14)
         .padding(.vertical, 12)
         .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .rideGlassCard(density: .hud)
      .accessibilityIdentifier(hasHome ? "planner.button.home" : "planner.button.setHome")
      .accessibilityHint(hasHome ? "Plans a bike route home from here" : "Opens the home address picker")
   }
}

// MARK: - Icons

private extension String {
   static let homeIcon = "house.fill"
   static let setHomeIcon = "house"
   static let goIcon = "arrow.turn.up.right"
   static let chevronIcon = "chevron.right"
}

#Preview {
   ZStack {
      Color.black.ignoresSafeArea()
      VStack(spacing: 12) {
         RouteHomeButton(homeLabel: "60th St, Newport News", onRideHome: {}, onSetHome: {})
         RouteHomeButton(homeLabel: nil, onRideHome: {}, onSetHome: {})
      }
      .padding()
   }
   .preferredColorScheme(.dark)
}
