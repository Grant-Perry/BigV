//
//  RideDetailTrackSection.swift
//  BigV
//

import MapKit
import SwiftUI

/// Map, headline, and Laps & Climbs as one instrument.
///
/// Resting, the hero sits between the preview and the list. While a split is
/// highlighted the hero collapses, the map grows, and the camera is live —
/// pinch, pan and rotate around the lit slice. The expand control still opens
/// the full-screen map; a tap on the idle preview does the same.
struct RideDetailTrackSection: View {

   let route: RideRoute
   let isLoaded: Bool
   let radarPasses: [RideRadarPassAnnotation]
   let header: RideDetailHeader?
   let laps: RideLapsReport?
   let highlight: RideRouteMapHighlight?

   @Binding var highlightedSplit: RideSplitID?
   @Binding var isScrubbing: Bool
   let onExpandMap: () -> Void

   @Environment(\.accessibilityReduceMotion) private var reduceMotion
   @State private var heroHeight = RideDetailHighlightLayout.fallbackHeroHeight
   @State private var cameraPosition: MapCameraPosition = .automatic

   var body: some View {
      VStack(spacing: 0) {
         mapSection
         Color.clear.frame(height: RideDetailHighlightLayout.stackSpacing)
         heroSection
         Color.clear.frame(height: trailingHeroSpacing)
         lapsSection
      }
      .animation(highlightAnimation, value: isGrowingMap)
      .onChange(of: highlightedSplit) { _, _ in
         frameCamera()
      }
   }

   // MARK: - Map

   private var mapSection: some View {
      RideRouteMapView(
         route: route,
         isLoaded: isLoaded,
         height: RideDetailHighlightLayout.mapHeight(
            isHighlighting: isGrowingMap,
            heroHeight: heroHeight
         ),
         radarPasses: radarPasses,
         highlight: highlight,
         interactionModes: isInspecting ? .all : [.pan, .zoom],
         cameraPosition: isInspecting ? $cameraPosition : nil
      )
      .overlay {
         if route.isDrawable, !isInspecting {
            Color.clear
               .contentShape(.rect)
               .onTapGesture(perform: onExpandMap)
         }
      }
      .overlay(alignment: .topLeading) {
         if route.isDrawable {
            RideRouteMapLegend(radarPasses: radarPasses)
               .padding(10)
               .allowsHitTesting(false)
         }
      }
      .overlay(alignment: .bottomTrailing) {
         if route.isDrawable {
            expandControl
         }
      }
      .accessibilityAddTraits(route.isDrawable && !isInspecting ? .isButton : [])
      .accessibilityHint(isInspecting ? "Pinch, pan, and rotate to inspect the highlighted split" : "Opens the route at full screen")
      .accessibilityValue(highlightedSplit?.accessibilityName ?? "Full ride")
      .accessibilityIdentifier("detail.map")
   }

   private var expandControl: some View {
      Button("Open full screen map", systemImage: "arrow.up.left.and.arrow.down.right", action: onExpandMap)
         .labelStyle(.iconOnly)
         .font(.caption.weight(.bold))
         .foregroundStyle(RideDashboardTheme.ink)
         .frame(width: 32, height: 32)
         .rideGlassChrome(in: .circle)
         .padding(10)
         .accessibilityIdentifier("detail.button.expandMap")
   }

   // MARK: - Hero

   @ViewBuilder
   private var heroSection: some View {
      if let header {
         RideDetailHeroCard(header: header)
            .background {
               GeometryReader { proxy in
                  Color.clear.preference(key: RideDetailHeroHeightKey.self, value: proxy.size.height)
               }
            }
            .onPreferenceChange(RideDetailHeroHeightKey.self) { height in
               guard height > 1 else { return }
               heroHeight = height
            }
            .frame(height: isGrowingMap ? 0 : nil, alignment: .top)
            .opacity(isGrowingMap ? 0 : 1)
            .clipped()
            .allowsHitTesting(!isGrowingMap)
            .accessibilityHidden(isGrowingMap)
            .detailCardEntrance()
      }
   }

   // MARK: - Laps

   @ViewBuilder
   private var lapsSection: some View {
      if let laps {
         RideLapsCard(
            report: laps,
            highlightedSplit: $highlightedSplit,
            isScrubbing: $isScrubbing
         )
         .detailCardEntrance()
      }
   }

   // MARK: - Layout

   private var isGrowingMap: Bool {
      highlightedSplit != nil && header != nil
   }

   /// A pinned split turns the preview into a live map, even when there is no
   /// hero to collapse — the camera still has to be free.
   private var isInspecting: Bool {
      highlightedSplit != nil
   }

   private var trailingHeroSpacing: CGFloat {
      if header == nil || isGrowingMap {
         return 0
      }
      return RideDetailHighlightLayout.stackSpacing
   }

   private var highlightAnimation: Animation? {
      reduceMotion ? nil : .smooth(duration: 0.32)
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

// MARK: - Hero height

private struct RideDetailHeroHeightKey: PreferenceKey {
   static var defaultValue: CGFloat = 0

   static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
      let next = nextValue()
      if next > 0 { value = next }
   }
}
