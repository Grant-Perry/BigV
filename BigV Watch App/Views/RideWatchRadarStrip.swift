//
//  RideWatchRadarStrip.swift
//  BigV Watch App
//

import SwiftUI

/// The rear road on one compact line: a horizontal tape with the nearest
/// vehicle's pip, its distance, and how many are back there.
///
/// The mirror carries aggregates only — count, nearest, tier — so the strip
/// draws the nearest vehicle and says the rest with a number. Same rear-view
/// convention as the phone tape, laid on its side: the rider anchors the
/// LEADING edge (right beside the radar glyph) and vehicles enter far away at
/// the trailing edge, sliding toward the rider as they close from behind.
/// The near-field expansion idea carries over too: the last 40 m are most of
/// the track, because that is where decisions happen.
struct RideWatchRadarStrip: View {

   let isConnected: Bool
   let tier: RideRadarThreatTier?
   let vehicleCount: Int
   let nearestDistanceMeters: Double?
   let nearestDistanceText: String?

   /// The RTL515's rated range, the far end of the track.
   private static let maxDistanceMeters: Double = 140

   var body: some View {
      HStack(spacing: 6) {
         Image(systemName: .radarIcon)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tierColor)

         track

         Text(readout)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(readoutColor)
            .lineLimit(1)
            .fixedSize()
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Rear radar")
      .accessibilityValue(accessibilitySummary)
   }

   // MARK: - Track

   private var track: some View {
      GeometryReader { proxy in
         ZStack(alignment: .leading) {
            Capsule()
               .fill(.white.opacity(isConnected ? 0.10 : 0.05))
               .frame(height: 3)

            // The rider's own mark, anchoring the near (leading) end.
            Circle()
               .fill(.white.opacity(isConnected ? 0.45 : 0.15))
               .frame(width: 3, height: 3)

            if isConnected, let fraction = nearestFraction {
               pip
                  .offset(x: (proxy.size.width - 8) * (1 - fraction))
            }
         }
         .frame(maxHeight: .infinity, alignment: .center)
      }
      .frame(height: 12)
   }

   /// 0 at the far (trailing) end, 1 at the rider, with a square-root
   /// expansion so the near field gets most of the pixels.
   private var nearestFraction: Double? {
      guard let nearestDistanceMeters else { return nil }

      let clamped = min(max(nearestDistanceMeters, 0), Self.maxDistanceMeters)
      return 1 - (clamped / Self.maxDistanceMeters).squareRoot()
   }

   /// Circle for an ordinary approach; a rotated square for the high tier so
   /// the escalation is never colour-only.
   @ViewBuilder private var pip: some View {
      if tier == .high {
         Rectangle()
            .fill(RideChromeTokens.halt)
            .frame(width: 6, height: 6)
            .rotationEffect(.degrees(45))
      } else {
         Circle()
            .fill(tierColor)
            .frame(width: 6, height: 6)
      }
   }

   // MARK: - Readout

   private var readout: String {
      guard isConnected else { return "OFF" }
      guard let nearestDistanceText else { return "CLEAR" }

      return vehicleCount > 1
         ? "\(vehicleCount) · \(nearestDistanceText)"
         : nearestDistanceText
   }

   // MARK: - Palette

   private var tierColor: Color {
      guard isConnected else { return .white.opacity(0.30) }

      return switch tier {
         case .high: RideChromeTokens.halt
         case .approaching: RideChromeTokens.amber
         case nil: RideChromeTokens.ice
      }
   }

   private var readoutColor: Color {
      guard isConnected else { return .white.opacity(0.40) }

      return switch tier {
         case .high: RideChromeTokens.halt
         case .approaching: RideChromeTokens.amber
         case nil: .white.opacity(0.60)
      }
   }

   // MARK: - Accessibility

   private var accessibilitySummary: String {
      guard isConnected else { return "Disconnected" }
      guard vehicleCount > 0, let nearestDistanceText else { return "Road clear behind" }

      let vehicles = vehicleCount == 1 ? "One vehicle" : "\(vehicleCount) vehicles"
      return "\(vehicles) approaching from behind, nearest \(nearestDistanceText)"
   }
}

private extension String {
   static let radarIcon = "car.rear.waves.up"
}

#Preview {
   VStack(spacing: 8) {
      RideWatchRadarStrip(
         isConnected: true, tier: nil, vehicleCount: 0,
         nearestDistanceMeters: nil, nearestDistanceText: nil
      )
      RideWatchRadarStrip(
         isConnected: true, tier: .approaching, vehicleCount: 1,
         nearestDistanceMeters: 82, nearestDistanceText: "82 m"
      )
      RideWatchRadarStrip(
         isConnected: true, tier: .high, vehicleCount: 3,
         nearestDistanceMeters: 21, nearestDistanceText: "21 m"
      )
      RideWatchRadarStrip(
         isConnected: false, tier: nil, vehicleCount: 0,
         nearestDistanceMeters: nil, nearestDistanceText: nil
      )
   }
   .padding()
   .background(RideChromeTokens.void)
}
