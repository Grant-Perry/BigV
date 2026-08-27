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

   var body: some View {
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
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(.white.opacity(0.06), in: .rect(cornerRadius: 14))
      .overlay(
         RoundedRectangle(cornerRadius: 14)
            .stroke(accent.opacity(0.35), lineWidth: 1)
      )
      .accessibilityIdentifier("dashboard.guidance")
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
}

#Preview {
   ZStack {
      Color.black
      RouteGuidanceStripView(routeGuidanceViewModel: RouteGuidanceViewModel())
         .padding()
   }
   .preferredColorScheme(.dark)
}
