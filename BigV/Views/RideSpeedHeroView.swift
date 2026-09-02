//
//  RideSpeedHeroView.swift
//  BigV
//

import SwiftUI

/// The number the rider actually looks at while moving.
///
/// Instrument-cluster energy: the speed dead centre on the ember plate, amber
/// unit, the heading ribbon directly beneath it, and AVG and MAX as glass
/// chips in the top corners so the three speeds a rider compares live in one
/// glance. Static — no per-frame animation competing with GPS. When the map
/// drawer is gone this is the hero, so the numeral grows.
struct RideSpeedHeroView: View {

   enum Layout: Sendable {
      case portrait
      case landscape
   }

   let value: String
   let unit: String
   let course: Double
   let heading: String
   let headingDegrees: String
   let isDimmed: Bool
   var isExpanded: Bool = false
   var layout: Layout = .portrait

   var averageValue: String? = nil
   var maximumValue: String? = nil
   var isSpeedChartSelected: Bool = false
   var onSelectSpeedChart: (() -> Void)? = nil

   private var hasSatellites: Bool {
      layout == .portrait && (averageValue != nil || maximumValue != nil)
   }

   /// The numeral grows into whatever the cockpit leaves the hero, so a Pro
   /// Max fills its plate and a small phone still fits its tiles. Height
   /// after the chips and the ribbon, and width after the unit, both get a
   /// say; the smaller wins, and the numeral's own minimum scale covers
   /// three-digit speeds beyond that.
   private func numeralSize(in size: CGSize) -> CGFloat {
      let ribbon: CGFloat = isExpanded ? 80 : 70
      switch layout {
         case .portrait:
            let chips: CGFloat = hasSatellites ? 34 : 0
            let byHeight = (size.height - 18 - chips - ribbon) / 1.18
            let byWidth = (size.width - 28 - 72) / 2.15
            return min(max(min(byHeight, byWidth), 64), isExpanded ? 184 : 168)
         case .landscape:
            let byHeight = (size.height - 18 - ribbon) / 1.18
            return min(max(byHeight, 44), 80)
      }
   }

   var body: some View {
      ZStack {
         emberPlate

         GeometryReader { geometry in
            let numeralSize = numeralSize(in: geometry.size)

            ZStack {
               glow(numeralSize: numeralSize)

               VStack(spacing: 0) {
                  if hasSatellites {
                     satellites
                  }

                  Spacer(minLength: 0)

                  speedLockup(numeralSize: numeralSize)

                  Spacer(minLength: 0)

                  RideHeadingRibbonView(
                     course: course,
                     heading: heading,
                     headingDegrees: headingDegrees,
                     isDimmed: isDimmed,
                     isExpanded: isExpanded && layout == .portrait
                  )
               }
               .padding(.horizontal, 14)
               .padding(.top, 10)
               .padding(.bottom, 8)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
         }
      }
      // Floors, not targets. The status row, tiles, drawer, and tab bar all
      // take their cut first — a tall floor here is how the chips used to
      // vanish under the notch. Compact yields; expanded still reads as hero.
      .frame(minHeight: minHeight)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipShape(.rect(cornerRadius: 24, style: .continuous))
      .overlay {
         RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(
               LinearGradient(
                  colors: [.white.opacity(0.22), .white.opacity(0.04), RideDashboardTheme.ember.opacity(0.14)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
               ),
               lineWidth: 1
            )
      }
   }

   private var minHeight: CGFloat {
      switch layout {
         case .portrait: isExpanded ? 260 : 196
         case .landscape: 150
      }
   }

   // MARK: - Speed

   private func speedLockup(numeralSize: CGFloat) -> some View {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
         Text(value)
            .font(.system(size: numeralSize, weight: .bold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(numeralColor)
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
            .accessibilityIdentifier("ride.speed")
            .accessibilityLabel("Speed")
            .accessibilityValue("\(value) \(unit)")

         Text(unit)
            .font(layout == .landscape ? .headline.weight(.bold) : (isExpanded ? .title.weight(.bold) : .title2.weight(.bold)))
            .foregroundStyle(isDimmed ? .white.opacity(0.28) : RideDashboardTheme.amber)
      }
      .frame(maxWidth: .infinity)
   }

   // MARK: - Satellites

   /// AVG in the leading corner, MAX in the trailing. Both tap through to the
   /// speed chart.
   private var satellites: some View {
      GlassEffectContainer(spacing: 8) {
         HStack {
            satellite("AVG", value: averageValue)
            Spacer(minLength: 8)
            satellite("MAX", value: maximumValue)
         }
      }
   }

   @ViewBuilder
   private func satellite(_ title: String, value: String?) -> some View {
      if let value {
         Button {
            onSelectSpeedChart?()
         } label: {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
               Text(title)
                  .font(.caption2.weight(.bold))
                  .kerning(1)
                  .foregroundStyle(isSpeedChartSelected ? RideDashboardTheme.ice : .white.opacity(0.55))

               Text(value)
                  .font(.system(size: 18, weight: .semibold, design: .rounded))
                  .monospacedDigit()
                  .lineLimit(1)
                  .minimumScaleFactor(0.7)
                  .foregroundStyle(isDimmed ? .white.opacity(0.4) : .white.opacity(0.94))

               Text(unit)
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(.white.opacity(0.42))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(.rect)
         }
         .buttonStyle(.plain)
         .disabled(onSelectSpeedChart == nil)
         .rideGlassChrome(in: .rect(cornerRadius: 12, style: .continuous))
         .overlay {
            if isSpeedChartSelected {
               RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .strokeBorder(RideDashboardTheme.ice.opacity(0.7), lineWidth: 1.5)
            }
         }
         .accessibilityLabel(title == "AVG" ? "Average speed" : "Maximum speed")
         .accessibilityValue("\(value) \(unit)")
         .accessibilityIdentifier(title == "AVG" ? "ride.tile.avgSpeed" : "ride.tile.maxSpeed")
      }
   }

   // MARK: - Cluster

   /// Fill only — never propose the photo's bitmap size, or the hero shoves
   /// the controls and map off the bottom of the dashboard.
   private var emberPlate: some View {
      Color.clear
         .overlay {
            RideTrailPlateView(plateName: RideAtmosphereScene.speedCluster.plateName)
         }
         .overlay {
            // Settle the bottom so the ribbon's letters read over the photo.
            LinearGradient(
               colors: [.clear, .clear, RideDashboardTheme.void.opacity(0.55)],
               startPoint: .top,
               endPoint: .bottom
            )
         }
         .clipped()
         .allowsHitTesting(false)
         .accessibilityHidden(true)
   }

   private var numeralColor: Color {
      isDimmed ? .white.opacity(0.35) : .white
   }

   private func glow(numeralSize: CGFloat) -> some View {
      Color.clear
         .overlay {
            Ellipse()
               .fill(
                  RadialGradient(
                     colors: [
                        (isDimmed ? Color.white : RideDashboardTheme.ice).opacity(isDimmed ? 0.05 : 0.22),
                        .clear
                     ],
                     center: .center,
                     startRadius: 8,
                     endRadius: 140
                  )
               )
               .frame(width: numeralSize * 2.6, height: numeralSize * 1.5)
               .blur(radius: 18)
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
         isDimmed: false,
         averageValue: "17.4",
         maximumValue: "31.2",
         onSelectSpeedChart: {}
      )
      .frame(height: 220)
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
         isExpanded: true,
         averageValue: "17.4",
         maximumValue: "31.2",
         isSpeedChartSelected: true,
         onSelectSpeedChart: {}
      )
      .padding()
   }
}

#Preview("Landscape") {
   ZStack {
      RideAtmosphereBackground()
      RideSpeedHeroView(
         value: "22.8",
         unit: "MPH",
         course: 47,
         heading: "NE",
         headingDegrees: "47°",
         isDimmed: false,
         layout: .landscape
      )
      .frame(width: 340, height: 170)
      .padding()
   }
}
