//
//  RideHeartPulseView.swift
//  BigVShared
//

import SwiftUI

/// BigMetric-style beating heart: custom outline with a swirling ice-to-pulse gradient.
///
/// One swirl turn and one lub-dub scale cycle per beat, locked to the same
/// clock — 90 BPM spins 50% faster than 60. Frozen on reduced luminance so
/// always-on displays do not burn compositor time.
struct RideHeartPulseView: View {

   let beatsPerMinute: Double?
   var isBeating: Bool = true
   var font: Font = .caption.weight(.semibold)

   @Environment(\.isLuminanceReduced) private var isLuminanceReduced

   var body: some View {
      let bpm = clampedRate
      let shouldAnimate = isBeating && bpm != nil && !isLuminanceReduced
      let size = iconSize

      TimelineView(.animation(minimumInterval: shouldAnimate ? 1.0 / 24.0 : 60, paused: !shouldAnimate)) { context in
         let rate = bpm ?? Self.restingRate
         let swirl = shouldAnimate ? Self.beatPhase(at: context.date, bpm: rate) : 0

         RideHeartIconShape()
            .stroke(
               style: StrokeStyle(
                  lineWidth: lineWidth,
                  lineCap: .round,
                  lineJoin: .round,
                  miterLimit: 0,
                  dash: shouldAnimate ? [150, 15] : [],
                  dashPhase: shouldAnimate ? swirl * Self.dashTravel : 0
               )
            )
            .frame(width: size, height: size)
            .foregroundStyle(shouldAnimate ? AnyShapeStyle(heartGradient(progress: swirl)) : AnyShapeStyle(RideChromeTokens.pulse.opacity(0.85)))
            .hueRotation(.degrees(shouldAnimate ? swirl * 360 : 0))
            .scaleEffect(shouldAnimate ? Self.lubDubScale(phase: swirl) : 1)
            .shadow(
               color: RideChromeTokens.pulse.opacity(shouldAnimate ? 0.45 : 0.15),
               radius: shouldAnimate ? 4 : 1
            )
      }
      .accessibilityHidden(true)
   }

   // MARK: - Style

   private func heartGradient(progress: Double) -> AngularGradient {
      AngularGradient(
         colors: [RideChromeTokens.ice, RideChromeTokens.pulse, RideChromeTokens.ice],
         center: .center,
         startAngle: .degrees(progress * 360),
         endAngle: .degrees(progress * 360 + 360)
      )
   }

   private var iconSize: CGFloat {
      switch font {
         case .largeTitle, .title, .title2, .title3: 28
         case .headline, .subheadline: 22
         default: 18
      }
   }

   private var lineWidth: CGFloat {
      max(2.5, iconSize * 0.12)
   }

   // MARK: - Rate

   private var clampedRate: Double? {
      guard let beatsPerMinute, RideWatchHeartRateReading.plausibleRange.contains(beatsPerMinute) else {
         return nil
      }
      return beatsPerMinute
   }

   /// `0...1` through the current beat. Same clock for swirl and lub-dub.
   private static func beatPhase(at date: Date, bpm: Double) -> Double {
      let cycle = 60.0 / bpm
      return date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle
   }

   // MARK: - Lub-dub

   private static func lubDubScale(phase: Double) -> CGFloat {
      switch phase {
         case ..<0.12:
            return 1.0 + 0.18 * easeOut(phase / 0.12)
         case ..<0.22:
            return 1.18 - 0.18 * easeIn((phase - 0.12) / 0.10)
         case ..<0.32:
            return 1.0 + 0.08 * easeOut((phase - 0.22) / 0.10)
         case ..<0.42:
            return 1.08 - 0.08 * easeIn((phase - 0.32) / 0.10)
         default:
            return 1.0
      }
   }

   private static func easeOut(_ t: Double) -> CGFloat {
      CGFloat(1 - pow(1 - t, 3))
   }

   private static func easeIn(_ t: Double) -> CGFloat {
      CGFloat(t * t * t)
   }

   private static let restingRate: Double = 72
   private static let dashTravel: CGFloat = 166
}

#Preview {
   HStack(spacing: 20) {
      RideHeartPulseView(beatsPerMinute: 68, font: .title2.weight(.semibold))
      RideHeartPulseView(beatsPerMinute: 142, font: .title2.weight(.semibold))
      RideHeartPulseView(beatsPerMinute: nil, isBeating: false, font: .title2.weight(.semibold))
   }
   .padding()
   .background(RideChromeTokens.void)
}
