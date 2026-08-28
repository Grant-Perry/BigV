//
//  RideSpeedHeroView.swift
//  BigV
//

import SwiftUI

/// The number the rider actually looks at while moving.
///
/// Instrument-cluster energy: glowing numerals, a live heading tape, amber
/// unit. Static — no per-frame animation competing with GPS. When the map
/// drawer is gone this is the hero, so the numeral and tape both grow.
struct RideSpeedHeroView: View {

   let value: String
   let unit: String
   let course: Double
   let heading: String
   let headingDegrees: String
   let isDimmed: Bool
   var isExpanded: Bool = false

   private var numeralSize: CGFloat { isExpanded ? 140 : 68 }

   var body: some View {
      ZStack {
         emberPlate
         glow

         VStack(spacing: isExpanded ? 12 : 6) {
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
                  .font(isExpanded ? .title2.weight(.bold) : .title3.weight(.bold))
                  .foregroundStyle(isDimmed ? .white.opacity(0.28) : RideDashboardTheme.amber)
            }

            RideHeadingTapeView(
               course: course,
               heading: heading,
               headingDegrees: headingDegrees,
               isDimmed: isDimmed,
               isExpanded: isExpanded
            )
            .padding(.horizontal, isExpanded ? 8 : 16)
         }
         .padding(.vertical, isExpanded ? 16 : 10)
      }
      .frame(minHeight: isExpanded ? 340 : 220)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipShape(.rect(cornerRadius: 24, style: .continuous))
   }

   // MARK: - Cluster

   /// Fill only — never propose the photo's bitmap size, or the hero shoves
   /// the controls and map off the bottom of the dashboard.
   private var emberPlate: some View {
      Color.clear
         .overlay {
            RideTrailPlateView(plateName: RideAtmosphereScene.speedCluster.plateName)
         }
         .clipped()
         .allowsHitTesting(false)
         .accessibilityHidden(true)
   }

   private var numeralColor: Color {
      isDimmed ? .white.opacity(0.35) : .white
   }

   private var glow: some View {
      Color.clear
         .overlay {
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
         }
         .allowsHitTesting(false)
         .accessibilityHidden(true)
   }
}

#Preview("Compact") {
   ZStack {
      RideAtmosphereBackground()
      RideSpeedHeroView(
         value: "22.8",
         unit: "MPH",
         course: 47,
         heading: "NE",
         headingDegrees: "47°",
         isDimmed: false
      )
      .frame(height: 180)
      .padding()
   }
}

#Preview("Expanded") {
   ZStack {
      RideAtmosphereBackground()
      RideSpeedHeroView(
         value: "22.8",
         unit: "MPH",
         course: 47,
         heading: "NE",
         headingDegrees: "47°",
         isDimmed: false,
         isExpanded: true
      )
      .padding()
   }
}
