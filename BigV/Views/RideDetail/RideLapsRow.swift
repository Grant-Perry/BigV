//
//  RideLapsRow.swift
//  BigV
//

import SwiftUI

/// One lap or climb line. The leading bar reserves its width whether the row
/// is selected or not, so sliding the list never shoves the numbers sideways.
struct RideLapsRow: View {

   let row: RideLapsReport.Row
   let splitID: RideSplitID
   let badgeTint: Color
   let isHighlighted: Bool
   var action: (() -> Void)?

   var body: some View {
      if let action {
         Button(action: action) {
            rowContent
         }
         .buttonStyle(.plain)
         .accessibilityHint(
            isHighlighted ? "Hides this split on the map" : "Shows this split on the map"
         )
         .accessibilityAddTraits(isHighlighted ? .isSelected : [])
         .accessibilityIdentifier(splitID.accessibilityIdentifier)
      } else {
         rowContent
            .accessibilityElement(children: .combine)
      }
   }

   // MARK: - Content

   private var rowContent: some View {
      HStack(spacing: 10) {
         Capsule()
            .fill(isHighlighted ? badgeTint : .clear)
            .frame(width: 3, height: 16)

         Text(row.badge)
            .font(.system(size: 10, weight: .bold))
            .kerning(0.6)
            .foregroundStyle(badgeTint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(badgeTint.opacity(isHighlighted ? 0.28 : 0.14), in: .capsule)
            .frame(width: 64, alignment: .leading)

         Text(row.timeText)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(RideDashboardTheme.ink)

         Text(row.distanceText)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(RideDashboardTheme.ink(0.6))

         Spacer()

         Text(row.detailText)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(RideDashboardTheme.ink(0.5))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
      }
      .padding(.horizontal, 4)
      .padding(.vertical, 4)
      .background {
         if isHighlighted {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
               .fill(badgeTint.opacity(0.12))
         }
      }
      .contentShape(.rect)
   }
}
