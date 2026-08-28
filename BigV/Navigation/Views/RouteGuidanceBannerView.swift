//
//  RouteGuidanceBannerView.swift
//  BigV
//

import SwiftUI

/// The next turn, sized to be read at a glance on a handlebar in direct sunlight.
///
/// Distance leads and the instruction follows, because at speed the rider is
/// asking "how far" before "which way". Nothing animates: the rerouting state is
/// stated in words rather than spun, since a spinner would run for seconds at a
/// time beside active GPS for no information gain.
struct RouteGuidanceBannerView: View {

   let routeGuidanceViewModel: RouteGuidanceViewModel
   let rideMapViewModel: RideMapViewModel

   var body: some View {
      VStack(alignment: .leading, spacing: 8) {
         banner

         if routeGuidanceViewModel.isTurnListPresented {
            RouteGuidanceTurnListView(
               routeGuidanceViewModel: routeGuidanceViewModel,
               onSelect: jump(to:)
            )
         }
      }
   }

   private var banner: some View {
      VStack(alignment: .leading, spacing: 10) {
         HStack(alignment: .top, spacing: 12) {
            headline
               .frame(maxWidth: .infinity, alignment: .leading)
               .contentShape(.rect)
               .onTapGesture(perform: toggleTurnList)

            if routeGuidanceViewModel.canPresentTurnList {
               Image(systemName: routeGuidanceViewModel.isTurnListPresented ? .collapseIcon : .expandIcon)
                  .font(.caption.weight(.bold))
                  .foregroundStyle(.white.opacity(0.45))
                  .padding(.top, 4)
                  .onTapGesture(perform: toggleTurnList)
            }

            controls
         }

         footer
            .contentShape(.rect)
            .onTapGesture(perform: toggleTurnList)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .rideGlassCard(density: .hud, cornerRadius: 20)
      .overlay(
         RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(accent.opacity(0.45), lineWidth: 1)
      )
      .sensoryFeedback(.impact(weight: .medium), trigger: routeGuidanceViewModel.turnPulse)
      .accessibilityIdentifier("guidance.banner")
      .accessibilityAddTraits(routeGuidanceViewModel.canPresentTurnList ? .isButton : [])
      .accessibilityHint(
         routeGuidanceViewModel.canPresentTurnList
            ? (routeGuidanceViewModel.isTurnListPresented ? "Hides the turn list" : "Shows all turns")
            : ""
      )
   }

   private func toggleTurnList() {
      routeGuidanceViewModel.toggleTurnList()
   }

   private func jump(to turn: PlannedRouteManeuver) {
      routeGuidanceViewModel.selectTurn(turn)
      rideMapViewModel.focusManeuver(id: turn.id, coordinate: turn.coordinate)
   }

   // MARK: - Headline

   @ViewBuilder
   private var headline: some View {
      if let statusTitle = routeGuidanceViewModel.statusTitle {
         status(title: statusTitle)
      } else {
         instruction
      }
   }

   private func status(title: String) -> some View {
      VStack(alignment: .leading, spacing: 3) {
         Text(title)
            .font(.title3.weight(.heavy))
            .kerning(1.5)
            .foregroundStyle(accent)
            .accessibilityIdentifier("guidance.status")

         if let detail = routeGuidanceViewModel.statusDetail {
            Text(detail)
               .font(.footnote.weight(.medium))
               .foregroundStyle(.white.opacity(0.7))
               .lineLimit(2)
         }
      }
   }

   @ViewBuilder
   private var instruction: some View {
      VStack(alignment: .leading, spacing: 2) {
         if let turnDistance = routeGuidanceViewModel.turnDistance {
            Text(turnDistance)
               .font(.system(size: 30, weight: .heavy, design: .rounded))
               .monospacedDigit()
               .foregroundStyle(accent)
               .accessibilityIdentifier("guidance.turnDistance")
         }

         Text(routeGuidanceViewModel.instruction ?? "Following route")
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .accessibilityIdentifier("guidance.instruction")

         if let following = routeGuidanceViewModel.followingInstruction {
            Text(following)
               .font(.caption.weight(.medium))
               .foregroundStyle(.white.opacity(0.55))
               .lineLimit(1)
         }

         if let notice = routeGuidanceViewModel.notice {
            Text(notice)
               .font(.caption2.weight(.semibold))
               .foregroundStyle(.orange)
               .lineLimit(2)
         }
      }
   }

   // MARK: - Controls

   private var controls: some View {
      RouteGuidanceControlsView(routeGuidanceViewModel: routeGuidanceViewModel)
   }

   // MARK: - Footer

   @ViewBuilder
   private var footer: some View {
      if !routeGuidanceViewModel.hasArrived {
         HStack(spacing: 14) {
            readout(
               title: "TO GO",
               value: "\(routeGuidanceViewModel.distanceRemaining) \(routeGuidanceViewModel.distanceRemainingUnit)"
            )

            readout(title: "ETA", value: routeGuidanceViewModel.arrivalTime)

            readout(title: "LEFT", value: routeGuidanceViewModel.timeRemaining)

            Spacer(minLength: 0)
         }
      }
   }

   private func readout(title: String, value: String) -> some View {
      HStack(spacing: 5) {
         Text(title)
            .font(.caption2.weight(.semibold))
            .kerning(0.8)
            .foregroundStyle(.white.opacity(0.45))

         Text(value)
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.9))
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(title)
      .accessibilityValue(value)
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
   static let expandIcon = "chevron.down"
   static let collapseIcon = "chevron.up"
}

#Preview {
   ZStack {
      Color.gray
      RouteGuidanceBannerView(
         routeGuidanceViewModel: RouteGuidanceViewModel(),
         rideMapViewModel: RideMapViewModel()
      )
      .padding()
   }
   .preferredColorScheme(.dark)
}
