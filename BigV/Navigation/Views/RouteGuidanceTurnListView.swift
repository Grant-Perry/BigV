//
//  RouteGuidanceTurnListView.swift
//  BigV
//

import SwiftUI

/// Every real step on the active route. One glass panel, wash rows — not a menu.
struct RouteGuidanceTurnListView: View {

   let routeGuidanceViewModel: RouteGuidanceViewModel
   let onSelect: (PlannedRouteManeuver) -> Void

   @Environment(\.verticalSizeClass) private var verticalSizeClass

   var body: some View {
      ScrollView {
         LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(routeGuidanceViewModel.turns) { turn in
               Button {
                  onSelect(turn)
               } label: {
                  row(turn)
               }
               .buttonStyle(.plain)
               .accessibilityIdentifier("guidance.turn.\(turn.id)")

               if turn.id != routeGuidanceViewModel.turns.last?.id {
                  Divider()
                     .overlay(Color.white.opacity(0.12))
               }
            }
         }
      }
      .scrollIndicators(.visible)
      .frame(maxHeight: verticalSizeClass == .compact ? 160 : 260)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .rideGlassChrome(in: .rect(cornerRadius: 16, style: .continuous))
      .accessibilityIdentifier("guidance.turnList")
   }

   // MARK: - Row

   private func row(_ turn: PlannedRouteManeuver) -> some View {
      let isUpcoming = turn.id == routeGuidanceViewModel.upcomingTurnID
      let isSelected = turn.id == routeGuidanceViewModel.selectedTurnID

      return HStack(alignment: .top, spacing: 12) {
         Image(systemName: PlannedRouteManeuverIcon.systemName(for: turn.instruction))
            .font(.body.weight(.semibold))
            .foregroundStyle(isUpcoming || isSelected ? RideDashboardTheme.ember : .white.opacity(0.8))
            .frame(width: 22)

         VStack(alignment: .leading, spacing: 2) {
            Text(turn.instruction)
               .font(.subheadline.weight(isUpcoming || isSelected ? .bold : .semibold))
               .foregroundStyle(.white)
               .fixedSize(horizontal: false, vertical: true)

            if let notice = turn.notice {
               Text(notice)
                  .font(.caption2.weight(.medium))
                  .foregroundStyle(.orange)
                  .fixedSize(horizontal: false, vertical: true)
            }
         }

         Spacer(minLength: 8)

         if let distance = routeGuidanceViewModel.distanceText(for: turn) {
            Text(distance)
               .font(.footnote.weight(.bold))
               .monospacedDigit()
               .foregroundStyle(isUpcoming ? RideDashboardTheme.ember : .white.opacity(0.65))
         }
      }
      .padding(.vertical, 10)
      .padding(.horizontal, 6)
      .background {
         if isSelected {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
               .fill(RideDashboardTheme.ember.opacity(0.16))
         }
      }
      .contentShape(.rect)
      .accessibilityElement(children: .combine)
      .accessibilityLabel(turn.instruction)
      .accessibilityValue(routeGuidanceViewModel.distanceText(for: turn) ?? "")
   }
}

// MARK: - Icon

enum PlannedRouteManeuverIcon {

   static func systemName(for instruction: String) -> String {
      let text = instruction.lowercased()

      if text.contains("u-turn") || text.contains("u turn") {
         return "arrow.uturn.down"
      }
      if text.contains("arrive") || text.contains("destination") {
         return "flag.fill"
      }
      if text.contains("left") {
         return "arrow.turn.up.left"
      }
      if text.contains("right") {
         return "arrow.turn.up.right"
      }
      if text.hasPrefix("start") || text.contains("continue") || text.contains("proceed") {
         return "arrow.up"
      }

      return "arrow.triangle.turn.up.right.diamond.fill"
   }
}
