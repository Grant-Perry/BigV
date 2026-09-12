//
//  RideHistoryRideCard.swift
//  BigV
//

import SwiftUI

/// One line of the logbook index.
///
/// A tap puts the ride on the stage above; a second tap on the same row, or
/// the chevron at its end, opens the full report. The selected row fills
/// ember and its number badge lights, so the "RIDE 10 OF 18" on the stage
/// points at exactly one line down here.
struct RideHistoryRideCard: View {

   let row: RideHistoryViewModel.Row
   let ordinal: Int
   let distanceUnit: String
   let isSelected: Bool
   let onSelect: () -> Void
   let onOpen: () -> Void

   var body: some View {
      HStack(alignment: .center, spacing: 10) {
         Button(action: onSelect) {
            HStack(alignment: .center, spacing: 12) {
               badge

               VStack(alignment: .leading, spacing: 3) {
                  Text(row.listDateText)
                     .font(.subheadline.weight(.semibold))
                     .foregroundStyle(isSelected ? RideDashboardTheme.ember : RideDashboardTheme.ink)
                     .lineLimit(1)
                     .minimumScaleFactor(0.85)

                  Text("\(row.durationText) · \(row.averageSpeedText) \(row.speedUnit) avg")
                     .font(.caption.weight(.medium))
                     .monospacedDigit()
                     .foregroundStyle(RideDashboardTheme.ink(isSelected ? 0.6 : 0.42))
                     .lineLimit(1)
               }

               Spacer(minLength: 8)

               HStack(alignment: .firstTextBaseline, spacing: 3) {
                  Text(row.distanceText)
                     .font(.system(size: 17, weight: .semibold, design: .rounded))
                     .monospacedDigit()
                     .foregroundStyle(RideDashboardTheme.ink)

                  Text(distanceUnit)
                     .font(.caption2.weight(.semibold))
                     .foregroundStyle(RideDashboardTheme.ink(0.45))
               }
            }
            .contentShape(.rect)
         }
         .buttonStyle(.plain)
         .accessibilityLabel("Ride \(ordinal), \(row.dateText)")
         .accessibilityValue("\(row.distanceText) \(distanceUnit), \(row.durationText)")
         .accessibilityHint(isSelected ? "Opens the full ride report" : "Shows this ride on the map")
         .accessibilityAddTraits(isSelected ? .isSelected : [])

         openButton
      }
      .padding(.leading, 12)
      .padding(.trailing, 10)
      .padding(.vertical, 10)
      .background {
         RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(RideDashboardTheme.ember.opacity(isSelected ? 0.16 : 0))
      }
      .overlay {
         RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(RideDashboardTheme.ember.opacity(isSelected ? 0.5 : 0), lineWidth: 1)
      }
      .accessibilityIdentifier(isSelected ? "history.row.selected" : "history.row")
   }

   // MARK: - Pieces

   /// The ride's place in the logbook, newest first. Lights ember when this
   /// is the ride on the stage.
   private var badge: some View {
      Text("\(ordinal)")
         .font(.system(size: 12, weight: .bold, design: .rounded))
         .monospacedDigit()
         .foregroundStyle(isSelected ? RideDashboardTheme.onAccent : RideDashboardTheme.ink(0.55))
         .frame(minWidth: 28, minHeight: 28)
         .background(
            isSelected ? RideDashboardTheme.ember : RideDashboardTheme.ink(0.08),
            in: .rect(cornerRadius: 8, style: .continuous)
         )
   }

   private var openButton: some View {
      Button("Open report", systemImage: "chevron.right", action: onOpen)
         .labelStyle(.iconOnly)
         .font(.caption.weight(.bold))
         .foregroundStyle(isSelected ? RideDashboardTheme.ember : RideDashboardTheme.ink(0.5))
         .frame(width: 30, height: 30)
         .contentShape(.circle)
         .accessibilityLabel("Open report for \(row.dateText)")
   }
}
