//
//  RideMetricTile.swift
//  BigV
//

import SwiftUI

/// One metric on the ride dashboard.
struct RideMetricTile: View {

   let title: String
   let value: String
   var unit: String?
   var identifier: String?

   var body: some View {
      VStack(alignment: .leading, spacing: 2) {
         Text(title)
            .font(.caption2.weight(.semibold))
            .kerning(1)
            .foregroundStyle(.white.opacity(0.55))

         HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
               .font(.system(size: 34, weight: .semibold, design: .rounded))
               .monospacedDigit()
               .foregroundStyle(.white)
               .lineLimit(1)
               .minimumScaleFactor(0.6)
               .accessibilityIdentifier(identifier ?? title)
               .accessibilityLabel(title)
               .accessibilityValue(unit.map { "\(value) \($0)" } ?? value)

            if let unit {
               Text(unit)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.white.opacity(0.45))
            }
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(Self.wash, in: .rect(cornerRadius: 16))
   }

   private static let wash = LinearGradient(
      colors: [.white.opacity(0.12), .white.opacity(0.04)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
   )
}

#Preview {
   ZStack {
      Color.black
      RideMetricTile(title: "DISTANCE", value: "12.84", unit: "MI")
         .padding()
   }
}
