//
//  RouteGuidanceControlsView.swift
//  BigV
//

import SwiftUI

/// Mute and end-navigation controls, shared by the map banner and the dashboard
/// strip.
///
/// Both surfaces carry them for the same reason: a rider who wants the voice to
/// stop, or the route gone, wants it on whichever screen is already in front of
/// them. Making them swipe to the map to find a button defeats the point of
/// having a dashboard.
struct RouteGuidanceControlsView: View {

   let routeGuidanceViewModel: RouteGuidanceViewModel

   /// Tap target. The map banner has room for a full-size control; the dashboard
   /// strip sits directly above the speed hero and gets a tighter one.
   var diameter: CGFloat = 38

   var body: some View {
      if routeGuidanceViewModel.hasArrived {
         Button("Done", action: routeGuidanceViewModel.dismissArrival)
            .font(.subheadline.weight(.bold))
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .accessibilityIdentifier("guidance.button.done")
      } else {
         HStack(spacing: 2) {
            circleButton(
               icon: routeGuidanceViewModel.isVoiceEnabled ? .voiceOnIcon : .voiceOffIcon,
               tint: routeGuidanceViewModel.isVoiceEnabled ? RideDashboardTheme.ink(0.85) : RideDashboardTheme.ink(0.35),
               label: routeGuidanceViewModel.voiceButtonLabel,
               hint: "Turn calls only. The route stays on the map.",
               identifier: "guidance.button.voice",
               action: routeGuidanceViewModel.toggleVoice
            )

            circleButton(
               icon: .endNavigationIcon,
               tint: RideDashboardTheme.ink(0.55),
               label: "End navigation",
               hint: "Clears the route and stops turn calls. The ride keeps recording.",
               identifier: "guidance.button.stop",
               action: routeGuidanceViewModel.endNavigation
            )
         }
      }
   }

   // MARK: - Button

   private func circleButton(
      icon: String,
      tint: Color,
      label: String,
      hint: String,
      identifier: String,
      action: @escaping () -> Void
   ) -> some View {
      Button(action: action) {
         Image(systemName: icon)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: diameter, height: diameter)
            .contentShape(.circle)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(label)
      .accessibilityHint(hint)
      .accessibilityIdentifier(identifier)
   }
}

// MARK: - Icons

private extension String {
   static let voiceOnIcon = "speaker.wave.2.fill"
   static let voiceOffIcon = "speaker.slash.fill"
   static let endNavigationIcon = "xmark"
}

#Preview {
   ZStack {
      Color.black
      RouteGuidanceControlsView(routeGuidanceViewModel: RouteGuidanceViewModel())
   }
   .preferredColorScheme(.dark)
}
