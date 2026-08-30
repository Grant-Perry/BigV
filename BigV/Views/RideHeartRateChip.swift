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
   var beatsPerMinute: Double?
   var isSelected: Bool = false
   var action: (() -> Void)?

   var body: some View {
      Group {
         if let action {
            Button(action: action) {
               chipContent
            }
            .buttonStyle(.plain)
         } else {
            chipContent
         }
      }
      .overlay {
         if isSelected {
            Capsule()
               .strokeBorder(RideChromeTokens.ice.opacity(0.85), lineWidth: 2)
         }
      }
   }

   private var chipContent: some View {
      RideSensorChip(value: value, tint: isSelected ? RideChromeTokens.ice.opacity(0.35) : nil) {
         RideHeartPulseView(
            beatsPerMinute: beatsPerMinute,
            isBeating: beatsPerMinute != nil,
            font: .caption.weight(.semibold)
         )
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Heart rate")
      .accessibilityValue("\(value) \(unit)")
      .accessibilityAddTraits(isSelected ? [.isSelected] : [])
      .accessibilityIdentifier("ride.chip.heartRate")
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      RideHeartRateChip(value: "142", unit: "BPM", beatsPerMinute: 142, isSelected: true, action: {})
         .padding()
   }
}
