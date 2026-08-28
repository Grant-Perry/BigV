//
//  RideRadarTapeView.swift
//  BigV
//

import SwiftUI

/// The rear-radar rail: a vertical tape in the Garmin rear-view convention —
/// the rider mark at the TOP, vehicles entering far away at the bottom and
/// climbing toward the rider as they close from behind.
///
/// Colour follows the industry convention exactly — amber approaching, red for
/// a fast approach, grey when empty, green reserved for the all-clear flash —
/// and the high tier also changes *shape* (diamond with a halo, not a dot) so
/// the escalation is never colour-only.
struct RideRadarTapeView: View {

   let tracks: [RideRadarTracker.Track]
   var isDimmed = false
   var unitSystem: RideUnitSystem = .current

   /// Rail width. The default is the compact strip the map and landscape
   /// cockpit use; the portrait dashboard passes `dashboardWidth` — a touch
   /// wider — and every glyph, tick, and font scales with it.
   var tapeWidth: CGFloat = Self.compactWidth

   static let compactWidth: CGFloat = 48

   /// Portrait-dashboard ribbon: slightly wider than the compact strip, run
   /// the full height of the upper dashboard column.
   static let dashboardWidth: CGFloat = 60

   /// How much bigger than the compact strip this instance is drawn.
   private var scale: CGFloat { max(1, tapeWidth / Self.compactWidth) }

   private var pipRadius: CGFloat { 5.5 * scale }

   private var nearestDistance: Double? {
      tracks.map(\.distanceMeters).min()
   }

   var body: some View {
      VStack(spacing: 4 * scale) {
         riderMark

         tape
            .mask(edgeFade)

         readout
      }
      .frame(width: tapeWidth)
      .animation(.smooth(duration: 0.25), value: tracks)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Rear radar")
      .accessibilityValue(accessibilitySummary)
      .accessibilityIdentifier("ride.radar")
   }

   // MARK: - Tape

   private var tape: some View {
      Canvas { context, size in
         drawRail(in: &context, size: size)

         for track in tracks where RideRadarTapeGeometry.isVisible(distance: track.distanceMeters) {
            drawPip(for: track, in: &context, size: size)
         }
      }
      .background(rail)
   }

   private var railCornerRadius: CGFloat { min(10 * scale, 16) }

   private var rail: some View {
      RoundedRectangle(cornerRadius: railCornerRadius, style: .continuous)
         .fill(
            LinearGradient(
               colors: [
                  RideChromeTokens.graphite.opacity(0.36),
                  RideChromeTokens.void.opacity(0.55)
               ],
               startPoint: .top,
               endPoint: .bottom
            )
         )
         .overlay {
            RoundedRectangle(cornerRadius: railCornerRadius, style: .continuous)
               .strokeBorder(.white.opacity(0.08), lineWidth: 1)
         }
   }

   // MARK: - Drawing

   private func drawRail(in context: inout GraphicsContext, size: CGSize) {
      let centerX = size.width / 2

      // Centerline the pips ride up.
      var lane = Path()
      lane.move(to: CGPoint(x: centerX, y: 2))
      lane.addLine(to: CGPoint(x: centerX, y: size.height - 4))
      context.stroke(
         lane,
         with: .color(chromeColor.opacity(0.30)),
         style: StrokeStyle(lineWidth: max(1, scale * 0.75), dash: [1.5 * scale, 5 * scale])
      )

      // Range ticks: the near-field boundary earns the strong one.
      for (distance, emphasis) in [(40.0, 0.5), (90.0, 0.28), (140.0, 0.28)] {
         let y = pipY(forDistance: distance, height: size.height)
         var tick = Path()
         tick.move(to: CGPoint(x: centerX - 7 * scale, y: y))
         tick.addLine(to: CGPoint(x: centerX + 7 * scale, y: y))
         context.stroke(tick, with: .color(chromeColor.opacity(emphasis)), lineWidth: max(1, scale * 0.75))
      }
   }

   private func drawPip(for track: RideRadarTracker.Track, in context: inout GraphicsContext, size: CGSize) {
      let center = CGPoint(
         x: RideRadarTapeGeometry.laneX(lateralOffset: track.lateralHook, width: size.width),
         y: pipY(forDistance: track.distanceMeters, height: size.height)
      )
      let color = tierColor(track.tier)

      // Amber circle = approaching vehicle; red diamond with halo = fast-closing (.high).
      switch track.tier {
         case .approaching:
            let pip = Path(ellipseIn: pipRect(around: center, radius: pipRadius))
            context.fill(pip, with: .color(color))
            context.stroke(pip, with: .color(color.opacity(0.5)), lineWidth: 2 * scale)

         case .high:
            // Shape is the cue, colour is the reinforcement.
            let halo = Path(ellipseIn: pipRect(around: center, radius: pipRadius + 4.5 * scale))
            context.stroke(halo, with: .color(color.opacity(0.55)), lineWidth: 1.5 * scale)

            let diamond = diamondPath(around: center, radius: pipRadius + 1.5 * scale)
            context.fill(diamond, with: .color(color))
      }
   }

   /// Rear-view mapping: distance zero (the rider) at the top of the tape, max
   /// range at the bottom — a closing vehicle's pip rises toward the rider.
   private func pipY(forDistance distance: Double, height: CGFloat) -> CGFloat {
      let inset = pipRadius + 5 * scale
      let usable = Double(height) - Double(inset) * 2
      return inset + CGFloat(RideRadarTapeGeometry.fraction(forDistance: distance) * usable)
   }

   private func pipRect(around center: CGPoint, radius: CGFloat) -> CGRect {
      CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
   }

   private func diamondPath(around center: CGPoint, radius: CGFloat) -> Path {
      var path = Path()
      path.move(to: CGPoint(x: center.x, y: center.y - radius))
      path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
      path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
      path.addLine(to: CGPoint(x: center.x - radius, y: center.y))
      path.closeSubpath()
      return path
   }

   // MARK: - Rider Mark

   /// Downward chevrons: traffic below on the tape is behind the rider,
   /// closing upward — the mark points back at what is coming.
   private var riderMark: some View {
      Image(systemName: .riderIcon)
         .font(.system(size: 13 * scale, weight: .bold))
         .foregroundStyle(isDimmed ? .white.opacity(0.30) : RideChromeTokens.ice)
         .accessibilityHidden(true)
   }

   // MARK: - Readout

   /// Handlebar-glanceable at dashboard scale, quiet at strip scale.
   private var readoutFont: Font {
      .system(size: 12 * scale, weight: scale > 1.15 ? .bold : .semibold, design: .rounded)
   }

   @ViewBuilder
   private var readout: some View {
      if let nearestDistance {
         Text(RideFormatters.radarDistance(nearestDistance, system: unitSystem))
            .font(readoutFont)
            .monospacedDigit()
            .foregroundStyle(readoutColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
      } else {
         Text("—")
            .font(readoutFont)
            .foregroundStyle(.white.opacity(0.28))
      }
   }

   private var readoutColor: Color {
      switch tracks.map(\.tier).max() {
         case .high: RideChromeTokens.halt
         case .approaching: RideChromeTokens.amber
         case nil: .white.opacity(0.45)
      }
   }

   // MARK: - Palette

   private var chromeColor: Color {
      isDimmed ? .white : RideChromeTokens.ice
   }

   private func tierColor(_ tier: RideRadarThreatTier) -> Color {
      if isDimmed {
         return .white.opacity(0.35)
      }
      return switch tier {
         case .approaching: RideChromeTokens.amber
         case .high: RideChromeTokens.halt
      }
   }

   /// Fades the far end of the tape — the bottom, where vehicles first appear.
   private var edgeFade: some View {
      LinearGradient(
         stops: [
            .init(color: .white, location: 0),
            .init(color: .white, location: 0.92),
            .init(color: .clear, location: 1)
         ],
         startPoint: .top,
         endPoint: .bottom
      )
   }

   // MARK: - Accessibility

   private var accessibilitySummary: String {
      guard !tracks.isEmpty else { return "No vehicles behind" }

      let count = tracks.count == 1 ? "One vehicle" : "\(tracks.count) vehicles"
      let urgency = tracks.contains { $0.tier == .high } ? "closing fast from behind" : "approaching from behind"

      guard let nearestDistance else { return "\(count) \(urgency)" }
      return "\(count) \(urgency), nearest \(RideFormatters.radarDistance(nearestDistance, system: unitSystem))"
   }
}

// MARK: - Side Placement

extension RideRadarSide {

   /// Where the tape sits when inserted as an overlay.
   var overlayAlignment: Alignment {
      self == .leading ? .leading : .trailing
   }

   /// The edge the tape pads against.
   var paddingEdge: Edge.Set {
      self == .leading ? .leading : .trailing
   }

   /// The edge the tape slides off when the radar link drops.
   var transitionEdge: Edge {
      self == .leading ? .leading : .trailing
   }
}

// MARK: - Lateral Hook

private extension RideRadarTracker.Track {

   /// The RTL515 has no lateral data; everything rides the centerline. An 820
   /// path fills this in without the view changing.
   var lateralHook: Double? { nil }
}

private extension String {
   static let riderIcon = "chevron.down.2"
}

#Preview("Traffic") {
   ZStack {
      RideAtmosphereBackground()

      HStack(spacing: 24) {
         RideRadarTapeView(tracks: [])
            .frame(height: 300)

         RideRadarTapeView(
            tracks: [
               .preview(id: 1, distance: 18, tier: .high),
               .preview(id: 2, distance: 55, tier: .approaching),
               .preview(id: 3, distance: 120, tier: .approaching)
            ]
         )
         .frame(height: 300)

         // Dashboard-scale ribbon: the full-height trailing gutter.
         RideRadarTapeView(
            tracks: [
               .preview(id: 1, distance: 32, tier: .high),
               .preview(id: 2, distance: 78, tier: .approaching)
            ],
            tapeWidth: RideRadarTapeView.dashboardWidth
         )
         .frame(height: 340)
      }
      .padding()
   }
}

private extension RideRadarTracker.Track {

   static func preview(id: UInt8, distance: Double, tier: RideRadarThreatTier) -> Self {
      Self(
         id: id,
         distanceMeters: distance,
         closingSpeedMetersPerSecond: tier == .high ? 9 : 4,
         timeToContact: distance / 8,
         tier: tier,
         firstSeenAt: .now,
         lastSeenAt: .now,
         minimumDistanceMeters: distance,
         maximumClosingSpeedMetersPerSecond: 9,
         peakTier: tier
      )
   }
}
