//
//  RideRadarPageView.swift
//  BigV
//

import SwiftUI

/// The full radar page: a two-lane corridor behind you — the rider ("YOU") at
/// the top, vehicles entering wide at the bottom and rising into a pinch as
/// they close from behind.
///
/// Same convention as the tape — amber approaching, red closing fast with a
/// redundant shape cue, grey when empty — at a size the rider can read at a
/// glance with the phone on the bars.
struct RideRadarPageView: View {

   let rideViewModel: RideViewModel
   let onShowRadar: () -> Void

   var body: some View {
      VStack(spacing: 10) {
         header

         RideRadarRoadView(
            tracks: rideViewModel.radarTracks,
            isDimmed: rideViewModel.isRadarDimmed,
            isConnected: rideViewModel.isRadarConnected,
            unitSystem: rideViewModel.unitSystem
         )
         .frame(maxHeight: .infinity)

         RideRadarDataStrip(rideViewModel: rideViewModel)
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 6)
      .accessibilityIdentifier("ride.page.radar")
   }

   // MARK: - Header

   private var header: some View {
      HStack(spacing: 8) {
         Image(systemName: "car.rear.waves.up")
            .font(.caption.weight(.semibold))
            .foregroundStyle(rideViewModel.isRadarConnected ? RideDashboardTheme.ice : RideDashboardTheme.ink(0.4))

         Text("REAR RADAR")
            .font(.caption2.weight(.bold))
            .kerning(1.2)
            .foregroundStyle(RideDashboardTheme.ink(0.7))

         Spacer()

         Text(connectionLabel)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(rideViewModel.isRadarConnected ? RideDashboardTheme.ice.opacity(0.8) : RideDashboardTheme.amber)

         Button(action: onShowRadar) {
            Image(systemName: "gearshape.fill")
               .font(.caption.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ink(0.7))
               .frame(width: 36, height: 36)
               .contentShape(.circle)
         }
         .buttonStyle(.plain)
         .rideGlassChrome(in: Circle())
         .accessibilityLabel("Radar settings")
      }
      .padding(.horizontal, 4)
   }

   private var connectionLabel: String {
      switch rideViewModel.radarConnection {
         case .connected: "LIVE"
         case .scanning: "SEARCHING"
         case .connecting: "CONNECTING"
         case .disconnected: "DISCONNECTED"
      }
   }
}

// MARK: - Road

/// The road surface and its traffic. Pure rendering; every number it draws
/// comes from the tracker via the view model.
private struct RideRadarRoadView: View {

   let tracks: [RideRadarTracker.Track]
   let isDimmed: Bool
   let isConnected: Bool
   let unitSystem: RideUnitSystem

   /// Road pinches toward the rider at the top — far traffic sits in a wide
   /// corridor behind you and the lane narrows as a vehicle closes in.
   private static let nearWidthRatio: CGFloat = 0.56
   private static let laneInset: CGFloat = 26

   var body: some View {
      GeometryReader { proxy in
         let size = proxy.size

         ZStack {
            roadSurface(in: size)
            laneMarkings(in: size)
            rangeTicks(in: size)

            ForEach(tracks) { track in
               RideRadarVehicleMark(track: track, isDimmed: isDimmed, unitSystem: unitSystem)
                  .position(vehiclePosition(for: track, in: size))
            }

            riderMark(in: size)

            if tracks.isEmpty {
               emptyState
            }
         }
         .animation(.smooth(duration: 0.3), value: tracks)
      }
      .clipShape(.rect(cornerRadius: 24, style: .continuous))
      .overlay {
         RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(RideDashboardTheme.ink(0.08), lineWidth: 1)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Rear radar road")
      .accessibilityValue(accessibilitySummary)
   }

   // MARK: - Geometry

   /// Rear-view mapping, same as the tape: distance zero sits just below the
   /// rider mark at the top; max range at the bottom. Closing traffic rises.
   private func vehicleY(forDistance distance: Double, height: CGFloat) -> CGFloat {
      let topInset: CGFloat = 64
      let bottomInset: CGFloat = 28
      let usable = height - topInset - bottomInset
      return topInset + usable * CGFloat(RideRadarTapeGeometry.fraction(forDistance: distance))
   }

   private func roadWidth(atY y: CGFloat, in size: CGSize) -> CGFloat {
      let full = size.width - Self.laneInset * 2
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
      RideRadarRoadShape(nearWidthRatio: Self.nearWidthRatio, laneInset: Self.laneInset)
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
            style: StrokeStyle(lineWidth: 2, dash: [12, 14])
         )
      }
      .allowsHitTesting(false)
   }

   private func rangeTicks(in size: CGSize) -> some View {
      ZStack(alignment: .leading) {
         ForEach([40, 90, 140], id: \.self) { meters in
            Text(RideFormatters.radarDistance(Double(meters), system: unitSystem))
               .font(.system(size: 10, weight: .semibold, design: .rounded))
               .monospacedDigit()
               .foregroundStyle(RideDashboardTheme.ink(0.30))
               .position(
                  x: 24,
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
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(isDimmed ? RideDashboardTheme.ink(0.35) : RideDashboardTheme.ice)

         Text("YOU")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .kerning(1)
            .foregroundStyle(RideDashboardTheme.ink(0.45))
      }
      .position(x: size.width / 2, y: 32)
      .accessibilityHidden(true)
   }

   // MARK: - Empty State

   private var emptyState: some View {
      VStack(spacing: 6) {
         Text(isConnected ? "ROAD CLEAR" : "RADAR OFFLINE")
            .font(.footnote.weight(.bold))
            .kerning(1.6)
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
private struct RideRadarVehicleMark: View {

   let track: RideRadarTracker.Track
   let isDimmed: Bool
   let unitSystem: RideUnitSystem

   /// Nearer vehicles draw larger, reinforcing the perspective.
   private var scale: CGFloat {
      1.35 - 0.55 * CGFloat(RideRadarTapeGeometry.fraction(forDistance: track.distanceMeters))
   }

   var body: some View {
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
      .overlay(alignment: .trailing) {
         Text(RideFormatters.radarDistance(track.distanceMeters, system: unitSystem))
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color.opacity(0.9))
            .fixedSize()
            .offset(x: 46 * scale)
      }
      .accessibilityHidden(true)
   }

   private var color: Color {
      if isDimmed { return RideDashboardTheme.ink(0.35) }
      return switch track.tier {
         case .approaching: RideDashboardTheme.amber
         case .high: RideDashboardTheme.halt
      }
   }
}

// MARK: - Data Strip

/// Count, nearest, closing speed, battery and link — the numbers under the road.
private struct RideRadarDataStrip: View {

   let rideViewModel: RideViewModel

   var body: some View {
      HStack(spacing: 0) {
         metric("VEHICLES", value: "\(rideViewModel.radarVehicleCount)")
         divider
         metric("NEAREST", value: rideViewModel.radarNearestDistance ?? RideFormatters.placeholder)
         divider
         metric(
            "CLOSING",
            value: rideViewModel.radarClosingSpeed ?? RideFormatters.placeholder,
            unit: rideViewModel.radarClosingSpeed != nil ? rideViewModel.speedUnit : nil
         )
         divider
         metric("BATTERY", value: rideViewModel.radarBattery ?? RideFormatters.placeholder)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .rideGlassCard(density: .hud)
      .accessibilityElement(children: .combine)
   }

   private func metric(_ label: String, value: String, unit: String? = nil) -> some View {
      VStack(spacing: 3) {
         HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
               .font(.system(size: 20, weight: .bold, design: .rounded))
               .monospacedDigit()
               .foregroundStyle(RideDashboardTheme.ink)

            if let unit {
               Text(unit)
                  .font(.system(size: 10, weight: .semibold))
                  .foregroundStyle(RideDashboardTheme.ink(0.4))
            }
         }

         Text(label)
            .font(.system(size: 9, weight: .bold))
            .kerning(0.8)
            .foregroundStyle(RideDashboardTheme.ink(0.45))
      }
      .frame(maxWidth: .infinity)
   }

   private var divider: some View {
      Rectangle()
         .fill(RideDashboardTheme.ink(0.10))
         .frame(width: 1, height: 30)
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      RideRadarPageView(rideViewModel: RideViewModel(), onShowRadar: {})
   }
   .preferredColorScheme(.dark)
}
