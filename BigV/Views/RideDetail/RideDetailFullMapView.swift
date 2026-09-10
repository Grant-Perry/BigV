//
//  RideDetailFullMapView.swift
//  BigV
//

import MapKit
import SwiftUI

/// The saved route at full screen: every gesture unlocked, and the same
/// Laps & Climbs piano as the report so a pin is not lost on the way in.
///
/// Presented from the ride detail map. Chrome floats on Liquid Glass; the
/// laps card docks under the map so pinch and rotate never compete with it.
struct RideDetailFullMapView: View {

   let route: RideRoute
   let radarPasses: [RideRadarPassAnnotation]
   let titleText: String
   var highlight: RideRouteMapHighlight? = nil
   var laps: RideLapsReport? = nil

   @Binding private var highlightedSplit: RideSplitID?
   @Binding private var isScrubbing: Bool

   @Environment(\.dismiss) private var dismiss
   @Environment(\.accessibilityReduceMotion) private var reduceMotion
   @State private var cameraPosition: MapCameraPosition = .automatic

   init(
      route: RideRoute,
      radarPasses: [RideRadarPassAnnotation],
      titleText: String,
      highlight: RideRouteMapHighlight? = nil,
      laps: RideLapsReport? = nil,
      highlightedSplit: Binding<RideSplitID?> = .constant(nil),
      isScrubbing: Binding<Bool> = .constant(false)
   ) {
      self.route = route
      self.radarPasses = radarPasses
      self.titleText = titleText
      self.highlight = highlight
      self.laps = laps
      _highlightedSplit = highlightedSplit
      _isScrubbing = isScrubbing
   }

   var body: some View {
      VStack(spacing: 0) {
         mapStage
         lapsDock
      }
      .background(RideDashboardTheme.void.ignoresSafeArea())
      .preferredColorScheme(.dark)
      .onAppear(perform: frameCamera)
      .onChange(of: highlightedSplit) { _, _ in
         frameCamera()
      }
   }

   // MARK: - Map

   private var mapStage: some View {
      ZStack(alignment: .top) {
         Map(position: $cameraPosition, interactionModes: .all) {
            RideRouteMapLayers(route: route, radarPasses: radarPasses, highlight: highlight)
         }
         .mapStyle(.rideRoute)
         .ignoresSafeArea(edges: .top)
         .accessibilityLabel("Full screen route map")
         .accessibilityValue(highlightedSplit?.accessibilityName ?? "Full ride")

         chrome

         VStack {
            Spacer()
            HStack {
               Spacer()
               RideRouteMapLegend(radarPasses: radarPasses)
                  .padding(.horizontal, 16)
                  .padding(.bottom, 8)
                  .allowsHitTesting(false)
            }
         }
      }
   }

   // MARK: - Laps

   @ViewBuilder
   private var lapsDock: some View {
      if let laps {
         RideLapsCard(
            report: laps,
            highlightedSplit: $highlightedSplit,
            isScrubbing: $isScrubbing
         )
         .padding(.horizontal, 16)
         .padding(.top, 10)
         .padding(.bottom, 12)
         .accessibilityIdentifier("detail.fullscreen.laps")
      }
   }

   // MARK: - Chrome

   private var chrome: some View {
      HStack(spacing: 12) {
         Text(titleText)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(RideDashboardTheme.ink)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .rideGlassChrome(in: .capsule)

         Spacer()

         Button("Close map", systemImage: "xmark", action: { dismiss() })
            .labelStyle(.iconOnly)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(RideDashboardTheme.ink)
            .frame(width: 38, height: 38)
            .rideGlassChrome(in: .circle)
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
   }

   // MARK: - Camera

   private func frameCamera() {
      let position = RideRouteMapCamera.position(highlight: highlight, route: route)
      if reduceMotion {
         cameraPosition = position
      } else {
         withAnimation(.smooth(duration: 0.35)) {
            cameraPosition = position
         }
      }
   }
}

#Preview {
   RideDetailFullMapView(route: .empty, radarPasses: [], titleText: "Aug 29 at 9:08 AM")
}
