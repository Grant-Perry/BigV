//
//  RideSpeedHeroView.swift
//  BigV
//

import SwiftUI

/// The number the rider actually looks at while moving.
struct RideSpeedHeroView: View {

   let value: String
   let unit: String
   let isDimmed: Bool

   var body: some View {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
         Text(value)
            .font(.system(size: 108, weight: .bold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityIdentifier("ride.speed")
            .accessibilityLabel("Speed")
            .accessibilityValue("\(value) \(unit)")

         Text(unit)
            .font(.title3.weight(.bold))
            .foregroundStyle(.white.opacity(0.5))
      }
      .foregroundStyle(isDimmed ? .white.opacity(0.35) : .white)
      .frame(maxWidth: .infinity)
   }
}

#Preview {
   ZStack {
      Color.black
      RideSpeedHeroView(value: "18.7", unit: "MPH", isDimmed: false)
   }
}
