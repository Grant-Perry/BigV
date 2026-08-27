//
//  RideSearchButton.swift
//  BigV
//

import SwiftUI

/// Magnifying-glass control that opens address search. Always visible.
struct RideSearchButton: View {

   enum Style {
      case chip
      case fab
   }

   let style: Style
   var identifier: String = "ride.button.search"
   let action: () -> Void

   var body: some View {
      Button(action: action) {
         Image(systemName: .searchIcon)
            .font(style == .fab ? .body.weight(.semibold) : .caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.92))
            .frame(width: size, height: size)
            .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .modifier(SearchGlassChrome(style: style))
      .accessibilityLabel("Search for an address")
      .accessibilityHint("Find a destination and plan a cycling route")
      .accessibilityIdentifier(identifier)
   }

   private var size: CGFloat {
      style == .fab ? RideDashboardTheme.fabSize : 36
   }
}

private struct SearchGlassChrome: ViewModifier {

   let style: RideSearchButton.Style

   func body(content: Content) -> some View {
      switch style {
         case .fab:
            content.rideGlassChrome(in: Circle())
         case .chip:
            content.rideGlassChrome(in: Capsule())
      }
   }
}

private extension String {
   static let searchIcon = "magnifyingglass"
}
