//
//  RideHistoryStage.swift
//  BigV
//

import MapKit
import SwiftUI

/// The fixed top of the Rides page: whichever ride the list has picked, shown
/// as its route and its headline numbers.
///
/// The map re-frames itself each time the selection moves, so flicking down
/// the list is a slideshow of routes. The whole stage is the door to the
/// full report, and the footer says so out loud.
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

   var body: some View {
      VStack(alignment: .leading, spacing: 0) {
         map

         VStack(alignment: .leading, spacing: 10) {
            header
            statRow
            reportFooter
         }
         .padding(.horizontal, 16)
         .padding(.bottom, 12)
      }
      .rideGlassCard(density: .standard, cornerRadius: 22)
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
         height: 176,
         interactionModes: [],
         cameraPosition: $cameraPosition
      )
      .clipShape(.rect(cornerRadius: 16, style: .continuous))
      .overlay {
         // A preview, not an instrument: the tap opens the report, where the
         // map can be pinched and scrubbed.
         Color.clear
            .contentShape(.rect)
            .onTapGesture(perform: onOpen)
      }
      .overlay(alignment: .topLeading) {
         if route.isDrawable {
            RideRouteMapLegend()
               .padding(8)
               .allowsHitTesting(false)
         }
      }
      .padding(8)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Route map")
      .accessibilityAddTraits(.isButton)
      .accessibilityHint("Opens the full ride report")
   }

   // MARK: - Header

   private var header: some View {
      HStack(alignment: .top) {
         VStack(alignment: .leading, spacing: 3) {
            Text(eyebrowText)
               .font(.caption2.weight(.bold))
               .kerning(1.4)
               .foregroundStyle(RideDashboardTheme.ember)
               .contentTransition(.numericText())

            Text(row.dateText)
               .font(.title3.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ink)
               .contentTransition(.numericText())
         }

         Spacer(minLength: 8)

         if let symbolName = row.weatherSymbolName, let temperature = row.temperatureText {
            HStack(spacing: 5) {
               Image(systemName: symbolName)
                  .font(.subheadline)
                  .symbolVariant(.fill)
                  .symbolRenderingMode(.multicolor)

               Text(temperature)
                  .font(.subheadline.weight(.semibold))
                  .monospacedDigit()
                  .foregroundStyle(RideDashboardTheme.ink(0.75))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Weather \(temperature)")
         }
      }
   }

   /// Newest first, so the first ride is the latest and every other one
   /// knows its place in the logbook.
   private var eyebrowText: String {
      ordinal <= 1 ? "LATEST RIDE" : "RIDE \(ordinal) OF \(rideCount)"
   }

   // MARK: - Stats

   private var statRow: some View {
      HStack(spacing: 0) {
         stageStat(row.distanceText, unit: distanceUnit, title: "DISTANCE")
         stageStat(row.durationText, unit: nil, title: "TIME")
         stageStat(row.averageSpeedText, unit: row.speedUnit, title: "AVG")
         stageStat(row.maximumSpeedText, unit: row.speedUnit, title: "MAX")
      }
   }

   private func stageStat(_ value: String, unit: String?, title: String) -> some View {
      VStack(alignment: .leading, spacing: 2) {
         Text(title)
            .font(.caption2.weight(.semibold))
            .kerning(0.8)
            .foregroundStyle(RideDashboardTheme.ink(0.42))

         HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
               .font(.system(size: 20, weight: .semibold, design: .rounded))
               .monospacedDigit()
               .foregroundStyle(RideDashboardTheme.ink)
               .contentTransition(.numericText())

            if let unit {
               Text(unit)
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(RideDashboardTheme.ink(0.45))
            }
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)
      .accessibilityLabel(title)
      .accessibilityValue(unit.map { "\(value) \($0)" } ?? value)
   }

   // MARK: - Footer

   private var reportFooter: some View {
      VStack(spacing: 8) {
         Rectangle()
            .fill(RideDashboardTheme.ink(0.08))
            .frame(height: 1)

         Button(action: onOpen) {
            HStack(spacing: 6) {
               Text("VIEW FULL REPORT")
                  .font(.caption2.weight(.bold))
                  .kerning(1.2)

               if row.vehicleCount > 0 {
                  Spacer(minLength: 8)

                  HStack(spacing: 4) {
                     Image(systemName: "car.rear.fill")
                        .font(.caption2)
                        .foregroundStyle(RideDashboardTheme.amber)

                     Text("\(row.vehicleCount)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(RideDashboardTheme.ink(0.55))
                  }
                  .accessibilityLabel("\(row.vehicleCount) vehicles tracked by radar")
               }

               Spacer(minLength: 8)

               Image(systemName: "chevron.right")
                  .font(.caption2.weight(.bold))
                  .opacity(0.8)
            }
            .foregroundStyle(RideDashboardTheme.ember)
            .contentShape(.rect)
         }
         .buttonStyle(.plain)
         .accessibilityLabel("View full report for \(row.dateText)")
         .accessibilityIdentifier("history.button.openReport")
      }
   }

   // MARK: - Camera

   private func frameCamera() {
      let position = RideRouteMapCamera.position(highlight: nil, route: route)
      if reduceMotion {
         cameraPosition = position
      } else {
         withAnimation(.smooth(duration: 0.4)) {
            cameraPosition = position
         }
      }
   }
}
