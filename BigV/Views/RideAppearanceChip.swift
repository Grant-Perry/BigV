//
//  RideAppearanceChip.swift
//  BigV
//

import SwiftUI

/// The day/night switch on the speedometer.
///
/// A glass circle on the status row, sized like Back to Start. It shows the
/// light it would switch *to* — a sun while the cockpit is dark, a moon while
/// it is light — because the rider tapping it in full sun is looking for the
/// sun, not for a description of what they already cannot read.
///
/// One tap flips between Day and Night outright. Automatic is chosen in
/// Settings; the chip never lands on it, so a rider blinded on the road is
/// never one tap away from "whatever the phone feels like".
struct RideAppearanceChip: View {

   @Environment(RideAppearanceSettings.self) private var appearanceSettings
   @Environment(\.colorScheme) private var colorScheme

   private var isDark: Bool { colorScheme == .dark }

   var body: some View {
      Button {
         withAnimation(.easeInOut(duration: 0.25)) {
            appearanceSettings.toggle(from: colorScheme)
         }
      } label: {
         Image(systemName: isDark ? "sun.max.fill" : "moon.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(isDark ? RideDashboardTheme.amber : RideDashboardTheme.ink(0.7))
            .frame(width: 34, height: 34)
            .contentShape(.circle)
            .contentTransition(.symbolEffect(.replace))
      }
      .buttonStyle(.plain)
      .rideGlassChrome(in: .circle)
      .accessibilityLabel(isDark ? "Switch to day mode" : "Switch to night mode")
      .accessibilityIdentifier("ride.chip.appearance")
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      RideAppearanceChip()
   }
   .environment(RideAppearanceSettings())
}
