//
//  RideWatchSpeedHero.swift
//  BigV Watch App
//

import SwiftUI

/// Speed, in the ice instrument light the phone uses for the same number.
///
/// The only metric big enough to read at a glance mid-corner, so it gets the whole
/// width and everything else gets a row.
struct RideWatchSpeedHero: View {

   let value: String
   let unit: String
   let isLive: Bool

   var body: some View {
      HStack(alignment: .firstTextBaseline, spacing: 3) {
         Text(value)
            .font(.system(size: 44, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(isLive ? RideChromeTokens.ice : Color.white.opacity(0.4))
            .lineLimit(1)
            .minimumScaleFactor(0.5)

         Text(unit)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white.opacity(0.45))
      }
      .frame(maxWidth: .infinity)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Speed")
      .accessibilityValue("\(value) \(unit)")
   }
}

#Preview {
   RideWatchSpeedHero(value: "18.4", unit: "MPH", isLive: true)
      .padding()
      .background(RideChromeTokens.void)
}
