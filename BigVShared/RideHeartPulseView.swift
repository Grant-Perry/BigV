//
//  RideHeartPulseView.swift
//  BigVShared
//

import SwiftUI

/// A heart that actually beats — lub-dub at the measured rate.
///
/// Frozen on a reduced-luminance display (Watch always-on, locked iPhone) so
/// we are not compositing 30 fps onto a dimmed screen for nobody.
struct RideHeartPulseView: View {

   let beatsPerMinute: Double?
   var isBeating: Bool = true
   var font: Font = .caption.weight(.semibold)

   @Environment(\.isLuminanceReduced) private var isLuminanceReduced

   var body: some View {
      let bpm = clampedRate
      let shouldBeat = isBeating && bpm != nil && !isLuminanceReduced

      TimelineView(.animation(minimumInterval: shouldBeat ? 1.0 / 24.0 : 60, paused: !shouldBeat)) { context in
         Image(systemName: .heartIcon)
            .font(font)
            .foregroundStyle(RideChromeTokens.pulse)
            .scaleEffect(Self.scale(at: context.date, bpm: bpm ?? Self.restingRate))
            .shadow(
               color: RideChromeTokens.pulse.opacity(shouldBeat ? 0.55 : 0),
               radius: shouldBeat ? 3 : 0
            )
      }
      .accessibilityHidden(true)
   }

   // MARK: - Rate

   /// Anything outside the sensor's plausible band is treated as rest, not a
   /// strobe and not a flatline.
   private var clampedRate: Double? {
      guard let beatsPerMinute, RideWatchHeartRateReading.plausibleRange.contains(beatsPerMinute) else {
         return nil
      }
      return beatsPerMinute
   }

   // MARK: - Waveform

   /// Systole then a smaller diastole, then rest. Matches what a rider feels,
   /// not a sine wave that never quite looks like a heart.
   private static func scale(at date: Date, bpm: Double) -> CGFloat {
      let cycle = 60.0 / bpm
      let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle

      switch phase {
         case ..<0.12:
            return 1.0 + 0.22 * Self.easeOut(phase / 0.12)
         case ..<0.22:
            return 1.22 - 0.22 * Self.easeIn((phase - 0.12) / 0.10)
         case ..<0.32:
            return 1.0 + 0.10 * Self.easeOut((phase - 0.22) / 0.10)
         case ..<0.42:
            return 1.10 - 0.10 * Self.easeIn((phase - 0.32) / 0.10)
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

private extension String {
   static let heartIcon = "heart.fill"
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
