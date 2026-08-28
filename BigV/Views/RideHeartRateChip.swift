//
//  RideHeartRateChip.swift
//  BigV
//

import SwiftUI

/// Live pulse from the wrist, sitting on the status row rather than in the
/// metrics grid — it is a sensor readout, not a ride total.
struct RideHeartRateChip: View {

   let value: String
   let unit: String

   var body: some View {
      HStack(spacing: 6) {
         Image(systemName: .heartIcon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(RideDashboardTheme.pulse)

         Text(value)
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(.white)

         Text(unit)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.45))
      }
      .padding(.horizontal, 12)
      .frame(height: 36)
      .rideGlassChrome(in: Capsule())
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Heart rate")
      .accessibilityValue("\(value) \(unit)")
      .accessibilityIdentifier("ride.chip.heartRate")
   }
}

private extension String {
   static let heartIcon = "heart.fill"
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      RideHeartRateChip(value: "142", unit: "BPM")
         .padding()
   }
}
