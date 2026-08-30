//
//  RideDetailCardHeader.swift
//  BigV
//

import SwiftUI

/// The furniture every detail card shares: a tinted icon, a kerned title and
/// an optional trailing summary, so the sections read as one instrument panel.
struct RideDetailCardHeader: View {

   let icon: String
   let tint: Color
   let title: String
   var detail: String?

   var body: some View {
      HStack(spacing: 8) {
         Image(systemName: icon)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 22, height: 22)
            .background(tint.opacity(0.14), in: .rect(cornerRadius: 6, style: .continuous))

         Text(title)
            .font(.caption.weight(.bold))
            .kerning(1.2)
            .foregroundStyle(.white.opacity(0.75))

         Spacer(minLength: 8)

         if let detail {
            Text(detail)
               .font(.caption.weight(.semibold))
               .monospacedDigit()
               .foregroundStyle(.white.opacity(0.55))
               .lineLimit(1)
               .minimumScaleFactor(0.8)
         }
      }
      .accessibilityElement(children: .combine)
   }
}

// MARK: - Footnote Stat

/// One small labelled figure in a card's footer row.
struct RideDetailFootnoteStat: View {

   let label: String
   let value: String
   var unit: String?
   var tint: Color = .white

   var body: some View {
      VStack(alignment: .leading, spacing: 1) {
         Text(label)
            .font(.caption2.weight(.semibold))
            .kerning(0.8)
            .foregroundStyle(.white.opacity(0.45))
            .lineLimit(1)

         HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
               .font(.system(size: 17, weight: .semibold, design: .rounded))
               .monospacedDigit()
               .foregroundStyle(tint)
               .lineLimit(1)
               .minimumScaleFactor(0.7)

            if let unit {
               Text(unit)
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(.white.opacity(0.4))
            }
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)
      .accessibilityLabel(label)
      .accessibilityValue(unit.map { "\(value) \($0)" } ?? value)
   }
}

#Preview {
   ZStack {
      Color.black
      VStack(spacing: 20) {
         RideDetailCardHeader(
            icon: "mountain.2.fill",
            tint: RideDashboardTheme.ice,
            title: "ELEVATION",
            detail: "+20 / -25 FT"
         )

         HStack {
            RideDetailFootnoteStat(label: "MAX", value: "213", unit: "FT")
            RideDetailFootnoteStat(label: "MIN", value: "180", unit: "FT")
         }
      }
      .padding()
   }
   .preferredColorScheme(.dark)
}
