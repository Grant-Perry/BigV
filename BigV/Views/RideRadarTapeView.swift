//
//  RideRadarTapeView.swift
//  BigV
//

import SwiftUI

/// The rear-radar rail, in the Garmin rear-view convention: the rider mark at
/// the near end, vehicles entering far away and travelling toward the rider as
/// they close from behind.
///
/// Vertical placements put the rider at the TOP and traffic climbs. Horizontal
/// placements put the rider at the RIGHT and traffic runs in from the left. Both
/// read the same way — the pip moves toward the mark — so a rider who learns one
/// already knows the other.
///
/// Colour follows the industry convention exactly — amber approaching, red for
/// a fast approach, grey when empty, green reserved for the all-clear flash —
/// and the high tier also changes *shape* (diamond with a halo, not a dot) so
/// the escalation is never colour-only.
struct RideRadarTapeView: View {

   let tracks: [RideRadarTracker.Track]
   var isDimmed = false
   var unitSystem: RideUnitSystem = .current
   var placement: RideRadarPlacement = .trailing

   /// Cross-axis size: the rail's width when vertical, its height when
   /// horizontal. Every glyph, tick and font scales with it.
   var thickness: CGFloat = Self.compactWidth

   static let compactWidth: CGFloat = 48

   /// Portrait-dashboard ribbon: slightly wider than the compact strip.
   static let dashboardWidth: CGFloat = 60

   /// Horizontal bar height. Shorter than the vertical rails are wide — a
   /// top or bottom strip spends the screen's long axis on range instead.
   static let barThickness: CGFloat = 44

   private var isVertical: Bool { placement.isVertical }

   /// How much bigger than the compact strip this instance is drawn.
   private var scale: CGFloat { max(1, thickness / Self.compactWidth) }

   private var pipRadius: CGFloat { 5.5 * scale }

   private var nearestDistance: Double? {
      tracks.map(\.distanceMeters).min()
   }

   var body: some View {
      Group {
         if isVertical {
            VStack(spacing: 4 * scale) {
               riderMark

               tape
                  .mask(edgeFade)

               readout
            }
            .frame(width: thickness)
         } else {
            HStack(spacing: 4 * scale) {
               readout

               tape
                  .mask(edgeFade)

               riderMark
            }
            .frame(height: thickness)
         }
      }
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
                  RideDashboardTheme.graphite.opacity(0.36),
                  RideDashboardTheme.void.opacity(0.55)
               ],
               startPoint: .top,
               endPoint: .bottom
            )
         )
         .overlay {
            RoundedRectangle(cornerRadius: railCornerRadius, style: .continuous)
               .strokeBorder(RideDashboardTheme.ink(0.08), lineWidth: 1)
         }
   }

   // MARK: - Drawing

   private func drawRail(in context: inout GraphicsContext, size: CGSize) {
      let lineWidth = max(1, scale * 0.75)

      // Centerline the pips travel along.
      var lane = Path()
      lane.move(to: railPoint(along: 2, across: acrossCenter(in: size), in: size))
      lane.addLine(to: railPoint(along: extent(of: size) - 4, across: acrossCenter(in: size), in: size))
      context.stroke(
         lane,
         with: .color(chromeColor.opacity(0.30)),
         style: StrokeStyle(lineWidth: lineWidth, dash: [1.5 * scale, 5 * scale])
      )

      // Range ticks: the near-field boundary earns the strong one.
      for (distance, emphasis) in [(40.0, 0.5), (90.0, 0.28), (140.0, 0.28)] {
         let along = alongPosition(forDistance: distance, extent: extent(of: size))
         let center = acrossCenter(in: size)

         var tick = Path()
         tick.move(to: railPoint(along: along, across: center - 7 * scale, in: size))
         tick.addLine(to: railPoint(along: along, across: center + 7 * scale, in: size))
         context.stroke(tick, with: .color(chromeColor.opacity(emphasis)), lineWidth: lineWidth)
      }
   }

   private func drawPip(for track: RideRadarTracker.Track, in context: inout GraphicsContext, size: CGSize) {
      let center = railPoint(
         along: alongPosition(forDistance: track.distanceMeters, extent: extent(of: size)),
         across: RideRadarTapeGeometry.laneX(
            lateralOffset: track.lateralHook,
            width: crossExtent(of: size)
         ),
         in: size
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

   // MARK: - Axis Mapping
   //
   // Everything below works in tape space: `along` runs from the rider mark
   // (distance zero) out to max range, `across` is the lane offset. Only
   // `railPoint` knows which way that maps onto the screen, so the rear-view
   // convention is written once instead of once per placement.

   private func extent(of size: CGSize) -> CGFloat {
      isVertical ? size.height : size.width
   }

   private func crossExtent(of size: CGSize) -> CGFloat {
      isVertical ? size.width : size.height
   }

   private func acrossCenter(in size: CGSize) -> CGFloat {
      crossExtent(of: size) / 2
   }

   /// Rear-view mapping: distance zero is the rider mark, max range is the far
   /// end — a closing vehicle's pip travels back toward the mark.
   private func alongPosition(forDistance distance: Double, extent: CGFloat) -> CGFloat {
      let inset = pipRadius + 5 * scale
      let usable = Double(extent) - Double(inset) * 2
      return inset + CGFloat(RideRadarTapeGeometry.fraction(forDistance: distance) * usable)
   }

   /// Vertical tapes grow downward from a rider at the top; horizontal tapes
   /// grow leftward from a rider at the right.
   private func railPoint(along: CGFloat, across: CGFloat, in size: CGSize) -> CGPoint {
      isVertical
         ? CGPoint(x: across, y: along)
         : CGPoint(x: size.width - along, y: across)
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

   /// The chevrons point back down the tape at what is coming: down on a
   /// vertical rail, left on a horizontal one.
   private var riderMark: some View {
      Image(systemName: isVertical ? .riderIconVertical : .riderIconHorizontal)
         .font(.system(size: 13 * scale, weight: .bold))
         .foregroundStyle(isDimmed ? RideDashboardTheme.ink(0.30) : RideDashboardTheme.ice)
         .accessibilityHidden(true)
   }

   // MARK: - Readout

   /// Handlebar-glanceable at dashboard scale, quiet at strip scale.
   private var readoutFont: Font {
      .system(size: 12 * scale, weight: scale > 1.15 ? .bold : .semibold, design: .rounded)
   }

   @ViewBuilder
   private var readout: some View {
      Group {
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
               .foregroundStyle(RideDashboardTheme.ink(0.28))
         }
      }
      // A horizontal readout sits inline with the rail, so it needs a reserved
      // width or the whole tape shifts every time the distance gains a digit.
      .frame(minWidth: isVertical ? nil : 38 * scale, alignment: .trailing)
   }

   private var readoutColor: Color {
      switch tracks.map(\.tier).max() {
         case .high: RideDashboardTheme.halt
         case .approaching: RideDashboardTheme.amber
         case nil: RideDashboardTheme.ink(0.45)
      }
   }

   // MARK: - Palette

   private var chromeColor: Color {
      isDimmed ? RideDashboardTheme.ink : RideDashboardTheme.ice
   }

   private func tierColor(_ tier: RideRadarThreatTier) -> Color {
      if isDimmed {
         return RideDashboardTheme.ink(0.35)
      }
      return switch tier {
         case .approaching: RideDashboardTheme.amber
         case .high: RideDashboardTheme.halt
      }
   }

   /// Fades the far end of the tape, where vehicles first appear.
   private var edgeFade: some View {
      LinearGradient(
         stops: [
            .init(color: .white, location: 0),
            .init(color: .white, location: 0.92),
            .init(color: .clear, location: 1)
         ],
         startPoint: isVertical ? .top : .trailing,
         endPoint: isVertical ? .bottom : .leading
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

// MARK: - Placement

extension RideRadarPlacement {

   /// Where the tape sits when laid over the cockpit.
   var overlayAlignment: Alignment {
      switch self {
         case .leading: .leading
         case .trailing: .trailing
         case .top: .top
         case .bottom: .bottom
      }
   }

   /// The edge the tape slides off when the radar link drops.
   var transitionEdge: Edge {
      switch self {
         case .leading: .leading
         case .trailing: .trailing
         case .top: .top
         case .bottom: .bottom
      }
   }

   /// The edge the tape is parked on, for clearance padding.
   var overlayEdge: Edge.Set {
      switch self {
         case .leading: .leading
         case .trailing: .trailing
         case .top: .top
         case .bottom: .bottom
      }
   }

   /// The tape's own cross-axis size at cockpit scale.
   var cockpitThickness: CGFloat {
      isVertical ? RideRadarTapeView.dashboardWidth : RideRadarTapeView.barThickness
   }
}

// MARK: - Lateral Hook

private extension RideRadarTracker.Track {

   /// The RTL515 has no lateral data; everything rides the centerline. An 820
   /// path fills this in without the view changing.
   var lateralHook: Double? { nil }
}

private extension String {
   static let riderIconVertical = "chevron.down.2"
   static let riderIconHorizontal = "chevron.left.2"
}

#Preview("Vertical") {
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

         RideRadarTapeView(
            tracks: [
               .preview(id: 1, distance: 32, tier: .high),
               .preview(id: 2, distance: 78, tier: .approaching)
            ],
            thickness: RideRadarTapeView.dashboardWidth
         )
         .frame(height: 340)
      }
      .padding()
   }
}

#Preview("Horizontal") {
   ZStack {
      RideAtmosphereBackground()

      VStack(spacing: 24) {
         RideRadarTapeView(tracks: [], placement: .top)

         RideRadarTapeView(
            tracks: [
               .preview(id: 1, distance: 18, tier: .high),
               .preview(id: 2, distance: 55, tier: .approaching),
               .preview(id: 3, distance: 120, tier: .approaching)
            ],
            placement: .bottom,
            thickness: RideRadarTapeView.barThickness
         )
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
