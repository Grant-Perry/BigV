//
//  RideWordmark.swift
//  BigV
//

import SwiftUI

/// Site lockup: Outfit ExtraBold, white → ice, a hair of ember shade underneath.
struct RideWordmark: View {

   var pointSize: CGFloat = 72

   var body: some View {
      Text("BigVelo")
         .font(RideBrandType.display(pointSize))
         .tracking(pointSize * -0.055)
         .foregroundStyle(Self.iceWash)
         .shadow(color: RideChromeTokens.ice.opacity(0.28), radius: 18, y: 10)
         .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
         .padding(.bottom, 6)
         .accessibilityLabel("BigVelo")
   }

   /// Matches the web face: `#ffffff → #d7eef8 → ice`.
   static let iceWash = LinearGradient(
      colors: [
         .white,
         Color(red: 0.843, green: 0.933, blue: 0.973),
         RideChromeTokens.ice
      ],
      startPoint: .top,
      endPoint: .bottom
   )
}

#Preview {
   ZStack {
      RideDashboardTheme.void
      RideWordmark(pointSize: 64)
   }
   .ignoresSafeArea()
}
