//
//  RouteGuidanceStripView.swift
//  BigV
//

import SwiftUI

/// The next turn, summarised for the dashboard page.
///
/// The dashboard is where a rider spends most of their attention, so a turn has
/// to reach them there too — swiping to the map to find out a corner is coming is
/// exactly the thing turn-by-turn guidance exists to prevent. Deliberately one
/// line taller than a status bar and no more: the speed hero underneath is still
/// the headline.
struct RouteGuidanceStripView: View {

   let routeGuidanceViewModel: RouteGuidanceViewModel
   let rideMapViewModel: RideMapViewModel

   var body: some View {
      VStack(alignment: .leading, spacing: 8) {
         strip

         if routeGuidanceViewModel.isTurnListPresented {
            RouteGuidanceTurnListView(
               routeGuidanceViewModel: routeGuidanceViewModel,
               onSelect: jump(to:)
            )
         }
      }
   }

   /// The turn readout takes the tap that expands the list; the controls sit
   /// outside it so muting or ending navigation never opens the turn list by
   /// accident.
   private var strip: some View {
      HStack(spacing: 6) {
         turnSummary
            .contentShape(.rect)
            .onTapGesture(perform: routeGuidanceViewModel.toggleTurnList)
            .accessibilityAddTraits(routeGuidanceViewModel.canPresentTurnList ? .isButton : [])
            .accessibilityHint(turnListHint)

         RouteGuidanceControlsView(
            routeGuidanceViewModel: routeGuidanceViewModel,
            diameter: 34
         )
      }
      .padding(.leading, 14)
      .padding(.trailing, 6)
      .padding(.vertical, 6)
      .rideGlassCard(density: .hud, cornerRadius: 14)
      .overlay(
         RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(accent.opacity(0.35), lineWidth: 1)
      )
      .accessibilityIdentifier("dashboard.guidance")
   }

   private var turnSummary: some View {
      HStack(spacing: 12) {
         Image(systemName: .guidanceIcon)
            .font(.footnote.weight(.bold))
            .foregroundStyle(accent)

         content

         Spacer(minLength: 0)

         if let turnDistance = routeGuidanceViewModel.turnDistance,
            routeGuidanceViewModel.showsInstruction {
            Text(turnDistance)
               .font(.system(size: 22, weight: .heavy, design: .rounded))
               .monospacedDigit()
               .foregroundStyle(accent)
               .accessibilityIdentifier("dashboard.guidance.turnDistance")
         }

         if routeGuidanceViewModel.canPresentTurnList {
            Image(systemName: routeGuidanceViewModel.isTurnListPresented ? .collapseIcon : .expandIcon)
               .font(.caption.weight(.bold))
               .foregroundStyle(.white.opacity(0.4))
         }
      }
      .padding(.vertical, 4)
   }

   private var turnListHint: String {
      guard routeGuidanceViewModel.canPresentTurnList else { return "" }
      return routeGuidanceViewModel.isTurnListPresented ? "Hides the turn list" : "Shows all turns"
   }

   private func jump(to turn: PlannedRouteManeuver) {
      routeGuidanceViewModel.selectTurn(turn)
      rideMapViewModel.focusManeuver(id: turn.id, coordinate: turn.coordinate)
   }

   // MARK: - Content

   @ViewBuilder
   private var content: some View {
      if let statusTitle = routeGuidanceViewModel.statusTitle {
         VStack(alignment: .leading, spacing: 1) {
            Text(statusTitle)
               .font(.subheadline.weight(.heavy))
               .kerning(1)
               .foregroundStyle(accent)

            if let detail = routeGuidanceViewModel.statusDetail {
               Text(detail)
                  .font(.caption2)
                  .foregroundStyle(.white.opacity(0.6))
                  .lineLimit(1)
            }
         }
      } else {
         Text(routeGuidanceViewModel.instruction ?? "Following route")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .accessibilityIdentifier("dashboard.guidance.instruction")
      }
   }

   // MARK: - Accent

   private var accent: Color {
      if routeGuidanceViewModel.hasArrived { return .green }
      if routeGuidanceViewModel.isAlerting { return .red }
      return PlannedRouteStyle.line
   }
}

// MARK: - Icons

private extension String {
   static let guidanceIcon = "arrow.triangle.turn.up.right.diamond.fill"
   static let expandIcon = "chevron.down"
   static let collapseIcon = "chevron.up"
}

#Preview {
   ZStack {
      Color.black
      RouteGuidanceStripView(
         routeGuidanceViewModel: RouteGuidanceViewModel(),
         rideMapViewModel: RideMapViewModel()
      )
      .padding()
   }
   .preferredColorScheme(.dark)
}
