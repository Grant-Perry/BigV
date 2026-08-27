//
//  RideSpeedHeroView.swift
//  BigV
//

import SwiftUI

/// The number the rider actually looks at while moving.
///
/// Instrument-cluster energy: glowing numerals, a tick rail, amber unit. Static
/// — no per-frame animation competing with GPS.
struct RideSpeedHeroView: View {

   let value: String
   let unit: String
   let isDimmed: Bool
   var numeralSize: CGFloat = 108

   var body: some View {
      VStack(spacing: 10) {
         ZStack {
            emberPlate
            glow

            VStack(spacing: 8) {
               HStack(alignment: .firstTextBaseline, spacing: 8) {
                  Text(value)
                     .font(.system(size: numeralSize, weight: .bold, design: .rounded))
                     .monospacedDigit()
                     .lineLimit(1)
                     .minimumScaleFactor(0.5)
                     .foregroundStyle(numeralColor)
                     .accessibilityIdentifier("ride.speed")
                     .accessibilityLabel("Speed")
                     .accessibilityValue("\(value) \(unit)")

                  Text(unit)
                     .font(.title3.weight(.bold))
                     .foregroundStyle(isDimmed ? .white.opacity(0.28) : RideDashboardTheme.amber)
               }

               tickRail
            }
         }
         .frame(minHeight: numeralSize * 1.35)
         .clipShape(.rect(cornerRadius: 24, style: .continuous))

         Capsule()
            .fill(isDimmed ? .white.opacity(0.12) : RideDashboardTheme.ember.opacity(0.88))
            .frame(width: 54, height: 3)
      }
      .frame(maxWidth: .infinity)
   }

   // MARK: - Cluster

   private var emberPlate: some View {
      RideTrailPlateView(plateName: RideAtmosphereScene.speedCluster.plateName)
         .frame(maxWidth: .infinity, maxHeight: .infinity)
         .clipped()
         .allowsHitTesting(false)
         .accessibilityHidden(true)
   }



   private var numeralColor: Color {
      isDimmed ? .white.opacity(0.35) : .white
   }

   private var glow: some View {
      Ellipse()
         .fill(
            RadialGradient(
               colors: [
                  (isDimmed ? Color.white : RideDashboardTheme.ice).opacity(isDimmed ? 0.05 : 0.20),
                  .clear
               ],
               center: .center,
               startRadius: 8,
               endRadius: 140
            )
         )
         .frame(width: numeralSize * 2.8, height: numeralSize * 1.4)
         .blur(radius: 16)
         .allowsHitTesting(false)
         .accessibilityHidden(true)
   }

   private var tickRail: some View {
      HStack(spacing: 6) {
         ForEach(0..<21, id: \.self) { index in
            Capsule()
               .fill(tickColor(index))
               .frame(width: 1.5, height: tickHeight(index))
         }
      }
      .accessibilityHidden(true)
   }

   private func tickHeight(_ index: Int) -> CGFloat {
      if index == 10 { return 11 }
      return index.isMultiple(of: 5) ? 8 : 4
   }

   private func tickColor(_ index: Int) -> Color {
      let isCenter = index == 10
      if isDimmed {
         return .white.opacity(isCenter ? 0.28 : 0.12)
      }
      return isCenter ? RideDashboardTheme.ember : RideDashboardTheme.ice.opacity(0.45)
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      RideSpeedHeroView(value: "22.8", unit: "MPH", isDimmed: false)
   }
}
