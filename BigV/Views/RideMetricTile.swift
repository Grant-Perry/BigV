//
//  RideMetricTile.swift
//  BigV
//

import SwiftUI

/// One metric on the ride dashboard.
///
/// Left-column tiles trail into the gutter. Right-column tiles lead from it.
struct RideMetricTile: View {

   let title: String
   let value: String
   var unit: String?
   var identifier: String?
   var gutterAlignment: HorizontalAlignment = .leading

   /// Landscape packs three tiles across a short column, so the numeral and the
   /// padding both come down and the gutter alternation stops meaning anything.
   var isCompact: Bool = false

   var body: some View {
      VStack(alignment: isCompact ? .leading : gutterAlignment, spacing: 2) {
         Text(title)
            .font(.caption2.weight(.semibold))
            .kerning(isCompact ? 0.5 : 1)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(.white.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: frameAlignment)

         HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
               .font(.system(size: isCompact ? 26 : 34, weight: .semibold, design: .rounded))
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
         .frame(maxWidth: .infinity, alignment: frameAlignment)
      }
      .frame(maxWidth: .infinity, alignment: frameAlignment)
      .padding(.horizontal, isCompact ? 10 : 14)
      .padding(.vertical, isCompact ? 8 : 12)
      .rideGlassCard(density: .hud)
   }

   private var frameAlignment: Alignment {
      guard !isCompact else { return .leading }
      return gutterAlignment == .trailing ? .trailing : .leading
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      HStack(spacing: 10) {
         RideMetricTile(title: "DISTANCE", value: "12.84", unit: "MI", gutterAlignment: .trailing)
         RideMetricTile(title: "RIDE TIME", value: "1:12:04", gutterAlignment: .leading)
      }
      .padding()
   }
}
