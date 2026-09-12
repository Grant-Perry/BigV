//
//  RideHistoryStage.swift
//  BigV
//

import MapKit
import SwiftUI

/// The top of the Rides page: the selected ride's route, full-bleed, with
/// its name and numbers printed on the map itself.
///
/// Deliberately not a card. The list below is a stack of cards, and the
/// stage has to read as a different kind of thing — a picture with a
/// caption — so the eye never confuses the two. The camera re-frames each
/// time the selection moves; the pill in the corner is the door to the
/// full report, and so is a tap anywhere on the map.
struct RideHistoryStage: View {

   let row: RideHistoryViewModel.Row
   let ordinal: Int
   let rideCount: Int
   let distanceUnit: String
   let route: RideRoute
   let isRouteLoaded: Bool
   let onOpen: () -> Void

   @Environment(\.accessibilityReduceMotion) private var reduceMotion
   @State private var cameraPosition: MapCameraPosition = .automatic

   static let height: CGFloat = 300

   /// Points of map the chrome covers at the top (legend, pills) and the
   /// bottom (caption). The camera frames the route between them.
   private static let coveredTop: CGFloat = 52
   private static let coveredBottom: CGFloat = 140

   /// Keeps the caption clear of Apple's attribution in the bottom-left.
   private static let attributionClearance: CGFloat = 34

   var body: some View {
      ZStack(alignment: .bottomLeading) {
         map
         scrim
         caption
      }
      .frame(height: Self.height)
      .clipShape(
         UnevenRoundedRectangle(
            bottomLeadingRadius: 26,
            bottomTrailingRadius: 26,
            style: .continuous
         )
      )
      .overlay(alignment: .topLeading) {
         if route.isDrawable {
            RideRouteMapLegend()
               .padding(12)
               .allowsHitTesting(false)
         }
      }
      .overlay(alignment: .topTrailing) {
         HStack(spacing: 8) {
            weatherChip
            reportButton
         }
         .padding(12)
      }
      .onAppear(perform: frameCamera)
      // Keyed on the track, not the row: the route can land a pass after
      // the selection, and framing on the row would frame the old route.
      .onChange(of: route) { _, _ in
         frameCamera()
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("history.stage")
   }

   // MARK: - Map

   private var map: some View {
      RideRouteMapView(
         route: route,
         isLoaded: isRouteLoaded,
         height: Self.height,
         interactionModes: [],
         cameraPosition: $cameraPosition,
         isFramed: false
      )
      .overlay {
         // A preview, not an instrument: the tap opens the report, where the
         // map can be pinched and scrubbed.
         Color.clear
            .contentShape(.rect)
            .onTapGesture(perform: onOpen)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Route map for \(row.headlineDateText)")
      .accessibilityAddTraits(.isButton)
      .accessibilityHint("Opens the full ride report")
   }

   /// Darkens the bottom of the map so the caption reads over any basemap.
   private var scrim: some View {
      LinearGradient(
         stops: [
            .init(color: .clear, location: 0),
            .init(color: RideDashboardTheme.void.opacity(0.55), location: 0.45),
            .init(color: RideDashboardTheme.void.opacity(0.92), location: 1)
         ],
         startPoint: .top,
         endPoint: .bottom
      )
      .frame(height: 190)
      .frame(maxWidth: .infinity)
      .allowsHitTesting(false)
   }

   // MARK: - Caption

   private var caption: some View {
      VStack(alignment: .leading, spacing: 6) {
         Text(eyebrowText)
            .font(.caption2.weight(.bold))
            .kerning(1.4)
            .foregroundStyle(RideDashboardTheme.ember)
            .contentTransition(.numericText())

         Text(row.headlineDateText)
            .font(.title2.weight(.bold))
            .foregroundStyle(RideDashboardTheme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .contentTransition(.numericText())

         statRibbon
      }
      .padding(.horizontal, 18)
      .padding(.bottom, Self.attributionClearance)
      .allowsHitTesting(false)
   }

   /// Newest first, so the first ride is the latest and every other one
   /// knows its place in the logbook — and matches its badge in the list.
   private var eyebrowText: String {
      ordinal <= 1 ? "LATEST RIDE" : "RIDE \(ordinal) OF \(rideCount)"
   }

   private var statRibbon: some View {
      HStack(spacing: 10) {
         ribbonStat(row.distanceText, unit: distanceUnit)
         ribbonDot
         ribbonStat(row.durationText, unit: nil)
         ribbonDot
         ribbonStat(row.averageSpeedText, unit: "\(row.speedUnit) AVG")
         ribbonDot
         ribbonStat(row.maximumSpeedText, unit: "MAX")

         if row.vehicleCount > 0 {
            ribbonDot
            HStack(spacing: 3) {
               Image(systemName: "car.rear.fill")
                  .font(.caption2)
                  .foregroundStyle(RideDashboardTheme.amber)
               Text("\(row.vehicleCount)")
                  .font(.system(size: 15, weight: .semibold, design: .rounded))
                  .monospacedDigit()
                  .foregroundStyle(RideDashboardTheme.ink)
            }
            .accessibilityLabel("\(row.vehicleCount) vehicles tracked by radar")
         }
      }
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .accessibilityElement(children: .combine)
   }

   private func ribbonStat(_ value: String, unit: String?) -> some View {
      HStack(alignment: .firstTextBaseline, spacing: 3) {
         Text(value)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(RideDashboardTheme.ink)
            .contentTransition(.numericText())

         if let unit {
            Text(unit)
               .font(.system(size: 10, weight: .semibold))
               .foregroundStyle(RideDashboardTheme.ink(0.55))
         }
      }
   }

   private var ribbonDot: some View {
      Circle()
         .fill(RideDashboardTheme.ink(0.3))
         .frame(width: 3, height: 3)
   }

   // MARK: - Chrome

   @ViewBuilder
   private var weatherChip: some View {
      if let symbolName = row.weatherSymbolName, let temperature = row.temperatureText {
         HStack(spacing: 5) {
            Image(systemName: symbolName)
               .font(.caption)
               .symbolVariant(.fill)
               .symbolRenderingMode(.multicolor)

            Text(temperature)
               .font(.caption.weight(.semibold))
               .monospacedDigit()
               .foregroundStyle(RideDashboardTheme.ink(0.85))
         }
         .padding(.horizontal, 10)
         .padding(.vertical, 6)
         .background(RideDashboardTheme.veil(0.55), in: .capsule)
         .overlay {
            Capsule().strokeBorder(RideDashboardTheme.ink(0.12), lineWidth: 0.5)
         }
         .allowsHitTesting(false)
         .accessibilityElement(children: .combine)
         .accessibilityLabel("Weather \(temperature)")
      }
   }

   private var reportButton: some View {
      Button(action: onOpen) {
         HStack(spacing: 5) {
            Text("FULL REPORT")
               .font(.caption2.weight(.bold))
               .kerning(1.1)
            Image(systemName: "chevron.right")
               .font(.system(size: 9, weight: .bold))
         }
         .foregroundStyle(RideDashboardTheme.onAccent)
         .padding(.horizontal, 12)
         .padding(.vertical, 7)
         .background(RideDashboardTheme.ember, in: .capsule)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("View full report for \(row.dateText)")
      .accessibilityIdentifier("history.button.openReport")
   }

   // MARK: - Camera

   /// Frames the route in the strip of map the chrome leaves uncovered:
   /// widen the span so the route fits that strip, then slide the centre so
   /// the strip, not the whole map, is centred on the route.
   private func frameCamera() {
      let position = RideRouteMapCamera.position(
         highlight: nil,
         route: route,
         framedIn: Self.height,
         coveredTop: Self.coveredTop,
         coveredBottom: Self.coveredBottom
      )
      if reduceMotion {
         cameraPosition = position
      } else {
         withAnimation(.smooth(duration: 0.4)) {
            cameraPosition = position
         }
      }
   }
}
