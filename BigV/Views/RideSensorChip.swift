//
//  RideSensorChip.swift
//  BigV
//

import SwiftUI

/// One live reading on the status row: a glyph and a number, nothing else.
///
/// Shared by the sky, the heart and the road behind so all three measure the
/// same and none of them can ever compress. A chip that prints "8 B" where it
/// meant "89 BPM" is worse than no chip at all, so the value is fixed-size and
/// the status text beside it is what yields when the row runs out of width.
///
/// The unit word is deliberately absent. A heart glyph followed by 89 is beats
/// per minute on every bike computer ever made, and spelling it out cost the
/// row twelve points it did not have.
struct RideSensorChip<Glyph: View>: View {

   /// The reading. `nil` draws a glyph-only chip — a sensor that is present but
   /// has nothing to say yet.
   var value: String?
   var valueColor: Color = .white
   var tint: Color?
   @ViewBuilder let glyph: Glyph

   var body: some View {
      HStack(spacing: 6) {
         glyph

         if let value {
            Text(value)
               .font(.caption.weight(.bold))
               .monospacedDigit()
               .foregroundStyle(valueColor)
         }
      }
      .padding(.horizontal, value == nil ? 0 : 11)
      .frame(width: value == nil ? Self.height : nil, height: Self.height)
      .fixedSize(horizontal: true, vertical: false)
      .contentShape(.capsule)
      .rideGlassChrome(in: Capsule(), tint: tint)
   }

   /// Matches the status row's other controls.
   static var height: CGFloat { 36 }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()

      HStack(spacing: 8) {
         RideSensorChip(value: "74°") {
            Image(systemName: "cloud.sun.fill")
               .font(.caption.weight(.semibold))
               .symbolRenderingMode(.hierarchical)
               .foregroundStyle(RideChromeTokens.ice)
         }

         RideSensorChip(value: "142") {
            Image(systemName: "heart.fill")
               .font(.caption.weight(.semibold))
               .foregroundStyle(RideChromeTokens.pulse)
         }

         RideSensorChip(value: "42 ft", valueColor: RideChromeTokens.amber, tint: RideChromeTokens.amber.opacity(0.25)) {
            Image(systemName: "car.rear.waves.up")
               .font(.caption.weight(.semibold))
               .foregroundStyle(RideChromeTokens.amber)
         }

         RideSensorChip {
            Image(systemName: "cloud.slash")
               .font(.caption.weight(.semibold))
               .foregroundStyle(.white.opacity(0.4))
         }
      }
      .padding()
   }
   .preferredColorScheme(.dark)
}
