//
//  RideHeartRateMetricTile.swift
//  BigV
//

import SwiftUI

/// Live pulse in the metrics grid, trailing ALT. Same glass as the other
/// tiles; the beating heart is the glyph, not a system symbol.
///
/// Only mounted while a Watch is feeding a rate — an empty BPM card is worse
/// than a gap.
struct RideHeartRateMetricTile: View {

   let value: String
   let unit: String
   var beatsPerMinute: Double?
   var isSelected: Bool = false
   var isCompact: Bool = false
   var action: (() -> Void)?

   var body: some View {
      Group {
         if let action {
            Button(action: action) {
               tileContent
            }
            .buttonStyle(.plain)
         } else {
            tileContent
         }
      }
      .overlay {
         if isSelected {
            RoundedRectangle(cornerRadius: RideDashboardTheme.cardRadius, style: .continuous)
               .strokeBorder(RideChromeTokens.ice.opacity(0.85), lineWidth: 2)
         }
      }
   }

   private var tileContent: some View {
      VStack(alignment: .leading, spacing: 2) {
         Text("HEART")
            .font(.caption2.weight(.semibold))
            .kerning(isCompact ? 0.5 : 1)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(.white.opacity(isSelected ? 0.75 : 0.55))
            .frame(maxWidth: .infinity, alignment: .leading)

         HStack(alignment: .center, spacing: isCompact ? 6 : 8) {
            RideHeartPulseView(
               beatsPerMinute: beatsPerMinute,
               isBeating: beatsPerMinute != nil,
               font: isCompact ? .headline : .title3
            )

            HStack(alignment: .firstTextBaseline, spacing: 4) {
               Text(value)
                  .font(.system(size: isCompact ? 26 : 34, weight: .semibold, design: .rounded))
                  .monospacedDigit()
                  .foregroundStyle(.white)
                  .lineLimit(1)
                  .minimumScaleFactor(0.6)

               Text(unit)
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.white.opacity(0.45))
            }
         }
         .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, isCompact ? 10 : 14)
      .padding(.vertical, isCompact ? 8 : 12)
      .rideGlassCard(density: .hud)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Heart rate")
      .accessibilityValue("\(value) \(unit)")
      .accessibilityAddTraits(isSelected ? [.isSelected] : [])
      .accessibilityIdentifier("ride.tile.heartRate")
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      HStack(spacing: 10) {
         RideMetricTile(
            title: "ALT",
            value: "43",
            unit: "FT",
            gutterAlignment: .trailing
         )
         RideHeartRateMetricTile(
            value: "142",
            unit: "BPM",
            beatsPerMinute: 142,
            isSelected: true,
            action: {}
         )
      }
      .padding()
   }
   .preferredColorScheme(.dark)
}
