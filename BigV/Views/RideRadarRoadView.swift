//
//  RideRadarRoadView.swift
//  BigV
//

import SwiftUI

/// The two-lane corridor behind you — the rider ("YOU") at the top, vehicles
/// entering wide at the bottom and rising into a pinch as they close from
/// behind.
///
/// Drawn once, sized twice: the radar page gives it the whole screen, and the
/// Traffic page gives it a column beside the speed hero. The column keeps the
/// same convention at a smaller scale, so a rider who learns one already
/// knows the other. Pure rendering; every number it draws comes from the
/// tracker via the view model.
struct RideRadarRoadView: View {

   /// How much room the road has been given.
   enum Style: Sendable {
      /// Full radar page: labels ride beside the cars.
      case page

      /// Traffic column: half the width, so labels sit under the cars.
      case column
   }

   let tracks: [RideRadarTracker.Track]
   let isDimmed: Bool
   let isConnected: Bool
   let unitSystem: RideUnitSystem
   var style: Style = .page

   /// A single tap, where the host wants one — the Traffic column taps
   /// through to the full radar page.
   var onTap: (() -> Void)?

   /// Road pinches toward the rider at the top — far traffic sits in a wide
   /// corridor behind you and the lane narrows as a vehicle closes in.
   private static let nearWidthRatio: CGFloat = 0.56

   private var isColumn: Bool { style == .column }
   private var laneInset: CGFloat { isColumn ? 14 : 26 }
   private var cornerRadius: CGFloat { isColumn ? 18 : 24 }

   var body: some View {
      GeometryReader { proxy in
         let size = proxy.size

         ZStack {
            roadSurface(in: size)
            laneMarkings(in: size)
            rangeTicks(in: size)

            ForEach(tracks) { track in
               RideRadarVehicleMark(
                  track: track,
                  isDimmed: isDimmed,
                  unitSystem: unitSystem,
                  style: style
               )
               .position(vehiclePosition(for: track, in: size))
            }

            riderMark(in: size)

            if tracks.isEmpty {
               emptyState
            }
         }
         .animation(.smooth(duration: 0.3), value: tracks)
      }
      .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
      .overlay {
         RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(RideDashboardTheme.ink(0.08), lineWidth: 1)
      }
      .contentShape(.rect)
      .onTapGesture { onTap?() }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Rear radar road")
      .accessibilityValue(accessibilitySummary)
      .accessibilityHint(onTap == nil ? "" : "Opens the radar page")
      .accessibilityAddTraits(onTap == nil ? [] : .isButton)
   }

   // MARK: - Geometry

   /// Rear-view mapping: distance zero sits just below the rider mark at the
   /// top; max range at the bottom. Closing traffic rises. Uses the page
   /// curve so a pack of cars can occupy the height instead of stacking.
   private func vehicleY(forDistance distance: Double, height: CGFloat) -> CGFloat {
      let topInset: CGFloat = isColumn ? 46 : 52
      let bottomInset: CGFloat = isColumn ? 30 : 24
      let usable = height - topInset - bottomInset
      return topInset + usable * CGFloat(RideRadarTapeGeometry.pageFraction(forDistance: distance))
   }

   private func roadWidth(atY y: CGFloat, in size: CGSize) -> CGFloat {
      let full = size.width - laneInset * 2
      let progress = y / max(size.height, 1)
      // progress 0 (rider / near) → narrow; progress 1 (far) → full width.
      return full * (Self.nearWidthRatio + (1 - Self.nearWidthRatio) * progress)
   }

   private func vehiclePosition(for track: RideRadarTracker.Track, in size: CGSize) -> CGPoint {
      let y = vehicleY(forDistance: track.distanceMeters, height: size.height)
      return CGPoint(x: size.width / 2, y: y)
   }

   // MARK: - Surface

   private func roadSurface(in size: CGSize) -> some View {
      RideRadarRoadShape(nearWidthRatio: Self.nearWidthRatio, laneInset: laneInset)
         .fill(
            LinearGradient(
               colors: [
                  RideDashboardTheme.graphite.opacity(isDimmed ? 0.35 : 0.65),
                  RideDashboardTheme.void.opacity(0.9)
               ],
               startPoint: .top,
               endPoint: .bottom
            )
         )
   }

   private func laneMarkings(in size: CGSize) -> some View {
      Canvas { context, canvasSize in
         let color = (isDimmed ? RideDashboardTheme.ink : RideDashboardTheme.ice).opacity(0.28)

         // Edges follow the perspective taper.
         for side: CGFloat in [-1, 1] {
            var edge = Path()
            edge.move(to: CGPoint(
               x: canvasSize.width / 2 + side * roadWidth(atY: 0, in: canvasSize) / 2,
               y: 0
            ))
            edge.addLine(to: CGPoint(
               x: canvasSize.width / 2 + side * roadWidth(atY: canvasSize.height, in: canvasSize) / 2,
               y: canvasSize.height
            ))
            context.stroke(edge, with: .color(color), lineWidth: 1.5)
         }

         // Dashed centerline splits the two lanes.
         var center = Path()
         center.move(to: CGPoint(x: canvasSize.width / 2, y: 0))
         center.addLine(to: CGPoint(x: canvasSize.width / 2, y: canvasSize.height))
         context.stroke(
            center,
            with: .color(color.opacity(0.7)),
            style: StrokeStyle(lineWidth: 2, dash: isColumn ? [9, 11] : [12, 14])
         )
      }
      .allowsHitTesting(false)
   }

   private func rangeTicks(in size: CGSize) -> some View {
      ZStack(alignment: .leading) {
         ForEach([40, 90, 140], id: \.self) { meters in
            Text(RideFormatters.radarDistance(Double(meters), system: unitSystem))
               .font(.system(size: isColumn ? 11 : 13, weight: .semibold, design: .rounded))
               .monospacedDigit()
               .foregroundStyle(RideDashboardTheme.ink(0.38))
               .position(
                  x: isColumn ? 18 : 24,
                  y: vehicleY(forDistance: Double(meters), height: size.height)
               )
         }
      }
      .accessibilityHidden(true)
   }

   // MARK: - Rider

   private func riderMark(in size: CGSize) -> some View {
      VStack(spacing: 3) {
         Image(systemName: "bicycle")
            .font(.system(size: isColumn ? 18 : 22, weight: .semibold))
            .foregroundStyle(isDimmed ? RideDashboardTheme.ink(0.35) : RideDashboardTheme.ice)

         Text("YOU")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .kerning(1)
            .foregroundStyle(RideDashboardTheme.ink(0.45))
      }
      .position(x: size.width / 2, y: isColumn ? 28 : 32)
      .accessibilityHidden(true)
   }

   // MARK: - Empty State

   private var emptyState: some View {
      VStack(spacing: 6) {
         Text(isConnected ? "ROAD CLEAR" : "RADAR OFFLINE")
            .font((isColumn ? Font.caption2 : .footnote).weight(.bold))
            .kerning(isColumn ? 1.2 : 1.6)
            .foregroundStyle(RideDashboardTheme.ink(isConnected ? 0.45 : 0.35))

         if !isConnected {
            Text("Reconnecting…")
               .font(.caption2)
               .foregroundStyle(RideDashboardTheme.ink(0.3))
         }
      }
   }

   // MARK: - Accessibility

   private var accessibilitySummary: String {
      guard isConnected else { return "Radar disconnected" }
      guard !tracks.isEmpty else { return "Road clear behind" }

      let count = tracks.count == 1 ? "One vehicle" : "\(tracks.count) vehicles"
      let urgency = tracks.contains { $0.tier == .high }
         ? "closing fast from behind"
         : "approaching from behind"

      guard let nearest = tracks.map(\.distanceMeters).min() else { return "\(count) \(urgency)" }
      return "\(count) \(urgency), nearest \(RideFormatters.radarDistance(nearest, system: unitSystem))"
   }
}

// MARK: - Road Shape

/// The two-lane corridor: narrow at the rider (top), wide at max range (bottom),
/// so traffic funnels toward you as it closes from behind.
private nonisolated struct RideRadarRoadShape: Shape {

   let nearWidthRatio: CGFloat
   let laneInset: CGFloat

   func path(in rect: CGRect) -> Path {
      let farHalf = (rect.width - laneInset * 2) / 2
      let nearHalf = farHalf * nearWidthRatio
      let centerX = rect.midX

      var path = Path()
      path.move(to: CGPoint(x: centerX - nearHalf, y: rect.minY))
      path.addLine(to: CGPoint(x: centerX + nearHalf, y: rect.minY))
      path.addLine(to: CGPoint(x: centerX + farHalf, y: rect.maxY))
      path.addLine(to: CGPoint(x: centerX - farHalf, y: rect.maxY))
      path.closeSubpath()
      return path
   }
}

// MARK: - Vehicle Mark

/// One car on the road: a rear-view glyph, tier colour, and — for the high
/// tier — a halo ring so escalation is a shape change, never colour alone.
///
/// On the page the distance rides beside the car. In the column there is no
/// room beside it, so the number hangs underneath instead.
private struct RideRadarVehicleMark: View {

   let track: RideRadarTracker.Track
   let isDimmed: Bool
   let unitSystem: RideUnitSystem
   let style: RideRadarRoadView.Style

   /// Nearer vehicles draw larger, reinforcing the perspective.
   private var scale: CGFloat {
      let perspective = 1.35 - 0.55 * CGFloat(RideRadarTapeGeometry.pageFraction(forDistance: track.distanceMeters))
      return style == .column ? perspective * 0.8 : perspective
   }

   var body: some View {
      Group {
         if style == .column {
            VStack(spacing: 2) {
               glyph
               label
            }
         } else {
            glyph
               .overlay(alignment: .trailing) {
                  label
                     .alignmentGuide(.trailing) { $0[.leading] - 26 }
               }
         }
      }
      .accessibilityHidden(true)
   }

   private var glyph: some View {
      ZStack {
         if track.tier == .high {
            Circle()
               .stroke(color.opacity(0.5), lineWidth: 2)
               .frame(width: 52 * scale, height: 52 * scale)
         }

         Image(systemName: "car.rear.fill")
            .font(.system(size: 26 * scale, weight: .semibold))
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.55), radius: 8 * scale)
      }
   }

   private var label: some View {
      Text(RideFormatters.radarDistance(track.distanceMeters, system: unitSystem))
         .font(.system(size: style == .column ? 22 : 32, weight: .bold, design: .rounded))
         .monospacedDigit()
         .kerning(style == .column ? 0.8 : 1.4)
         .foregroundStyle(isDimmed ? RideDashboardTheme.ink(0.35) : RideDashboardTheme.ink)
         .shadow(color: .black.opacity(0.8), radius: 6, y: 1)
         .fixedSize()
   }

   private var color: Color {
      if isDimmed { return RideDashboardTheme.ink(0.35) }
      return switch track.tier {
         case .approaching: RideDashboardTheme.amber
         case .high: RideDashboardTheme.halt
      }
   }
}

#Preview("Page") {
   ZStack {
      RideAtmosphereBackground()
      RideRadarRoadView(
         tracks: [
            .preview(id: 1, distance: 18, tier: .high),
            .preview(id: 2, distance: 55, tier: .approaching),
            .preview(id: 3, distance: 120, tier: .approaching)
         ],
         isDimmed: false,
         isConnected: true,
         unitSystem: .imperial
      )
      .padding()
   }
   .preferredColorScheme(.dark)
}

#Preview("Column") {
   ZStack {
      RideAtmosphereBackground()
      HStack {
         Spacer()
         RideRadarRoadView(
            tracks: [
               .preview(id: 1, distance: 18, tier: .high),
               .preview(id: 2, distance: 55, tier: .approaching)
            ],
            isDimmed: false,
            isConnected: true,
            unitSystem: .imperial,
            style: .column,
            onTap: {}
         )
         .frame(width: 150, height: 380)
      }
      .padding()
   }
   .preferredColorScheme(.dark)
}

extension RideRadarTracker.Track {

   /// A scripted car for previews.
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
