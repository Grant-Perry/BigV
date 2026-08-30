//
//  RideHeartPulseView.swift
//  BigVShared
//

import SwiftUI

/// BigMetric-style beating heart: custom outline with a swirling ice-to-pulse gradient.
///
/// When a plausible BPM is present the swirl speeds up slightly and the heart
/// scales on a lub-dub curve. Frozen on reduced luminance so always-on displays
/// do not burn compositor time.
struct RideHeartPulseView: View {

   let beatsPerMinute: Double?
   var isBeating: Bool = true
   var font: Font = .caption.weight(.semibold)

   @Environment(\.isLuminanceReduced) private var isLuminanceReduced
   @State private var swirlPhase = false

   var body: some View {
      let bpm = clampedRate
      let shouldAnimate = isBeating && bpm != nil && !isLuminanceReduced
      let size = iconSize

      TimelineView(.animation(minimumInterval: shouldAnimate ? 1.0 / 24.0 : 60, paused: !shouldAnimate)) { context in
         RideHeartIconShape()
            .stroke(
               style: StrokeStyle(
                  lineWidth: lineWidth,
                  lineCap: .round,
                  lineJoin: .round,
                  miterLimit: 0,
                  dash: shouldAnimate ? [150, 15] : [],
                  dashPhase: swirlPhase ? -83 : 83
               )
            )
            .frame(width: size, height: size)
            .foregroundStyle(shouldAnimate ? AnyShapeStyle(heartGradient) : AnyShapeStyle(RideChromeTokens.pulse.opacity(0.85)))
            .hueRotation(.degrees(shouldAnimate && swirlPhase ? 0 : 360))
            .scaleEffect(shouldAnimate ? Self.lubDubScale(at: context.date, bpm: bpm ?? Self.restingRate) : 1)
            .shadow(
               color: RideChromeTokens.pulse.opacity(shouldAnimate ? 0.45 : 0.15),
               radius: shouldAnimate ? 4 : 1
            )
      }
      .onAppear {
         guard !isLuminanceReduced else { return }
         withAnimation(.linear(duration: swirlDuration(bpm: clampedRate)).repeatForever(autoreverses: false)) {
            swirlPhase.toggle()
         }
      }
      .onChange(of: clampedRate) { _, newRate in
         guard newRate != nil, !isLuminanceReduced else { return }
         swirlPhase = false
         withAnimation(.linear(duration: swirlDuration(bpm: newRate)).repeatForever(autoreverses: false)) {
            swirlPhase.toggle()
         }
      }
      .accessibilityHidden(true)
   }

   // MARK: - Style

   private var heartGradient: AngularGradient {
      AngularGradient(
         colors: [RideChromeTokens.ice, RideChromeTokens.pulse, RideChromeTokens.ice],
         center: .center,
         startAngle: .degrees(swirlPhase ? 360 : 0),
         endAngle: .degrees(swirlPhase ? 720 : 360)
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

   private func swirlDuration(bpm: Double?) -> TimeInterval {
      guard let bpm else { return 2.5 }
      // Faster pulse → slightly faster swirl, clamped so it never strobes.
      return min(3.0, max(1.6, 120.0 / bpm))
   }

   // MARK: - Lub-dub

   private static func lubDubScale(at date: Date, bpm: Double) -> CGFloat {
      let cycle = 60.0 / bpm
      let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle

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
