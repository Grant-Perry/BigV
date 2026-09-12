//
//  RideHistoryRideCard.swift
//  BigV
//

import SwiftUI

/// One ride in the logbook list.
///
/// A tap puts the ride on the stage above; a second tap on the same row, or
/// the chevron at its end, opens the full report. The selected row wears an
/// ember rail so the list always shows which ride the map is drawing.
struct RideHistoryRideCard: View {

   let row: RideHistoryViewModel.Row
   let distanceUnit: String
   let isSelected: Bool
   let onSelect: () -> Void
   let onOpen: () -> Void

   var body: some View {
      HStack(alignment: .center, spacing: 12) {
         Button(action: onSelect) {
            HStack(alignment: .center, spacing: 12) {
               rail

               VStack(alignment: .leading, spacing: 4) {
                  Text(row.dateText)
                     .font(.subheadline.weight(.semibold))
                     .foregroundStyle(isSelected ? RideDashboardTheme.ember : RideDashboardTheme.ink)

                  Text("\(row.averageSpeedText) \(row.speedUnit) avg · \(row.durationText)")
                     .font(.caption.weight(.medium))
                     .monospacedDigit()
                     .foregroundStyle(RideDashboardTheme.ink(0.45))
               }

               Spacer(minLength: 8)

               HStack(alignment: .firstTextBaseline, spacing: 3) {
                  Text(row.distanceText)
                     .font(.body.weight(.semibold))
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
         .accessibilityLabel(row.dateText)
         .accessibilityValue("\(row.distanceText) \(distanceUnit), \(row.durationText)")
         .accessibilityHint(isSelected ? "Opens the full ride report" : "Shows this ride on the map")
         .accessibilityAddTraits(isSelected ? .isSelected : [])

         openButton
      }
      .padding(.leading, 12)
      .padding(.trailing, 10)
      .padding(.vertical, 10)
      .rideGlassCard(density: isSelected ? .standard : .hud)
      .overlay {
         RoundedRectangle(cornerRadius: RideDashboardTheme.cardRadius, style: .continuous)
            .strokeBorder(RideDashboardTheme.ember.opacity(isSelected ? 0.55 : 0), lineWidth: 1)
      }
      .accessibilityIdentifier(isSelected ? "history.row.selected" : "history.row")
   }

   // MARK: - Pieces

   private var rail: some View {
      Capsule()
         .fill(isSelected ? RideDashboardTheme.ember : RideDashboardTheme.ink(0.14))
         .frame(width: 3, height: 30)
   }

   private var openButton: some View {
      Button("Open report", systemImage: "chevron.right", action: onOpen)
         .labelStyle(.iconOnly)
         .font(.caption.weight(.bold))
         .foregroundStyle(isSelected ? RideDashboardTheme.ember : RideDashboardTheme.ink(0.7))
         .frame(width: 32, height: 32)
         .rideGlassChrome(in: .circle)
         .accessibilityLabel("Open report for \(row.dateText)")
   }
}
