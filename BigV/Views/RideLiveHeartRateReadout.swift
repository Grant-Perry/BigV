//
//  RideLiveHeartRateReadout.swift
//  BigV
//

import SwiftUI

/// Large live pulse sitting directly under the speed hero when heart rate is selected.
struct RideLiveHeartRateReadout: View {

   let value: String
   let unit: String
   var beatsPerMinute: Double?
   var isDimmed: Bool = false

   var body: some View {
      HStack(alignment: .center, spacing: 12) {
         RideHeartPulseView(
            beatsPerMinute: beatsPerMinute,
            isBeating: beatsPerMinute != nil,
            font: .title3.weight(.semibold)
         )

         HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
               .font(.system(size: 44, weight: .bold, design: .rounded))
               .monospacedDigit()
               .foregroundStyle(isDimmed ? RideDashboardTheme.ink(0.35) : RideDashboardTheme.ink)
               .lineLimit(1)
               .minimumScaleFactor(0.7)

            Text(unit)
               .font(.subheadline.weight(.bold))
               .foregroundStyle(isDimmed ? RideDashboardTheme.ink(0.28) : RideDashboardTheme.pulse.opacity(0.85))
         }

         Spacer(minLength: 0)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .rideGlassCard(density: .hud)
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Heart rate")
      .accessibilityValue("\(value) \(unit)")
      .accessibilityIdentifier("ride.liveMetric.heartRateReadout")
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      RideLiveHeartRateReadout(value: "142", unit: "BPM", beatsPerMinute: 142)
         .padding()
   }
   .preferredColorScheme(.dark)
}
