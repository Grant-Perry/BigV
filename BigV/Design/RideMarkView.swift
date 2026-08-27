//
//  RideMarkView.swift
//  BigV
//

import SwiftUI

/// The cockpit chevron: ember when waiting, ice when the fix is live.
struct RideMarkView: View {

   var isLive: Bool

   var body: some View {
      Image(systemName: .markIcon)
         .font(.caption.weight(.heavy))
         .foregroundStyle(isLive ? RideDashboardTheme.ice : RideDashboardTheme.ember)
         .accessibilityHidden(true)
   }
}

private extension String {
   static let markIcon = "arrowtriangle.up.right.fill"
}
