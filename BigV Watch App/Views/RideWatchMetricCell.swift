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

   var body: some View {
      VStack(alignment: .leading, spacing: 0) {
         Text(title)
            .font(.system(size: 9, weight: .semibold))
            .kerning(0.6)
            .foregroundStyle(.white.opacity(0.45))

         HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
               .font(.system(size: 19, weight: .semibold, design: .rounded))
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
      RideWatchMetricCell(title: "TIME", value: "1:12:04")
   }
   .padding()
   .background(RideChromeTokens.void)
}
