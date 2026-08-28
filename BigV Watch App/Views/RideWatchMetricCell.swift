//
//  RideWatchMetricCell.swift
//  BigV Watch App
//

import SwiftUI

/// One small metric in the row beneath the speed hero.
struct RideWatchMetricCell: View {

   let title: String
   let value: String
   var unit: String?
   var tint: Color = .white
   var isDimmed = false
   var showsHeart = false
   var beatsPerMinute: Double?

   var body: some View {
      VStack(alignment: .leading, spacing: 0) {
         Text(title)
            .font(.system(size: 9, weight: .semibold))
            .kerning(0.6)
            .foregroundStyle(.white.opacity(0.45))

         HStack(alignment: .firstTextBaseline, spacing: 3) {
            if showsHeart {
               RideHeartPulseView(
                  beatsPerMinute: beatsPerMinute,
                  isBeating: !isDimmed && beatsPerMinute != nil,
                  font: .system(size: 12, weight: .semibold)
               )
               .offset(y: 1)
            }

            Text(value)
               .font(.system(size: 18, weight: .semibold, design: .rounded))
               .monospacedDigit()
               .foregroundStyle(isDimmed ? tint.opacity(0.4) : tint)
               .lineLimit(1)
               .minimumScaleFactor(0.6)

            if let unit {
               Text(unit)
                  .font(.system(size: 9, weight: .semibold))
                  .foregroundStyle(.white.opacity(0.35))
            }
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(title)
      .accessibilityValue(unit.map { "\(value) \($0)" } ?? value)
   }
}

#Preview {
   HStack {
      RideWatchMetricCell(title: "DIST", value: "12.84", unit: "MI")
      RideWatchMetricCell(
         title: "HEART",
         value: "67",
         unit: "BPM",
         tint: RideChromeTokens.pulse,
         showsHeart: true,
         beatsPerMinute: 67
      )
   }
   .padding()
   .background(RideChromeTokens.void)
}
