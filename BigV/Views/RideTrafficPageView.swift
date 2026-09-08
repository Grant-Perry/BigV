//
//  RideTrafficPageView.swift
//  BigV
//

import SwiftUI

/// The Traffic page: the radar road at a size you can read, with the speed,
/// the two totals and the map still on screen.
///
/// One swipe from the dashboard — the page a rider lives on in traffic. The
/// road is the same corridor the radar page draws, in a column beside the
/// hero rather than across the whole screen; the full page is one more swipe
/// on, or a tap on the road. The dashboard's tape is not drawn here: the road
/// is the tape, at a size that earns its space.
///
/// The road takes the side the rider parked the tape on. Only a left-hand
/// tape moves it left; every other placement reads on the right, beside the
/// hero, so the numbers and the road sit where the dashboard taught them to.
struct RideTrafficPageView: View {

   let rideViewModel: RideViewModel
   let rideMapViewModel: RideMapViewModel
   let routeGuidanceViewModel: RouteGuidanceViewModel
   var showsDrawerMap: Bool = true
   let onExpandMap: () -> Void
   let onShowRadar: () -> Void

   /// A tap on the road: the full radar page.
   let onShowRadarPage: () -> Void

   /// Forward is the page's job, as on the dashboard: the drawer pans.
   var onSwipeForward: () -> Void = {}

   @Environment(\.verticalSizeClass) private var verticalSizeClass
   @Environment(RideClimbModel.self) private var rideClimbModel
   @State private var isDrawerOpen = true

   var body: some View {
      Group {
         if verticalSizeClass == .compact {
            landscape
         } else {
            portrait
         }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .accessibilityIdentifier("ride.page.traffic")
   }

   // MARK: - Portrait

   private var portrait: some View {
      VStack(spacing: 10) {
         VStack(spacing: 10) {
            RideDashboardStatusRow(
               rideViewModel: rideViewModel,
               onShowRadar: onShowRadar
            )

            if routeGuidanceViewModel.isActive {
               RouteGuidanceStripView(
                  routeGuidanceViewModel: routeGuidanceViewModel,
                  rideMapViewModel: rideMapViewModel
               )
            }

            band
         }
         .contentShape(.rect)
         .simultaneousGesture(swipeForward)

         RideMapDrawer(
            rideMapViewModel: rideMapViewModel,
            isMapMounted: showsDrawerMap,
            onExpand: onExpandMap,
            isOpen: $isDrawerOpen
         )
         .overlay(alignment: .bottomTrailing) {
            RideControlBar(rideViewModel: rideViewModel, style: .compact)
               .padding(.trailing, 10)
               .padding(.bottom, 10)
         }
         .layoutPriority(1)
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 6)
   }

   /// The hero and its two cards on one side, the road on the other.
   ///
   /// The road gets a little under half the width — enough for a car and its
   /// distance stacked, never so much that the speed numeral shrinks past
   /// what a rider reads at a glance.
   private var band: some View {
      GeometryReader { proxy in
         let roadWidth = min(max(proxy.size.width * 0.42, 136), 176)

         HStack(spacing: 10) {
            if roadLeads {
               road.frame(width: roadWidth)
            }

            instrumentColumn

            if !roadLeads {
               road.frame(width: roadWidth)
            }
         }
      }
      .frame(maxHeight: .infinity)
   }

   private var roadLeads: Bool {
      rideViewModel.radarPlacement.trafficRoadLeads
   }

   private var instrumentColumn: some View {
      VStack(spacing: 10) {
         RideDashboardInstrumentHero(
            rideViewModel: rideViewModel,
            isExpanded: false,
            layout: .column
         )
         .frame(maxHeight: .infinity)
         .layoutPriority(-1)

         trafficCards(isCompact: false)
      }
      .frame(maxWidth: .infinity)
   }

   private var road: some View {
      RideRadarRoadView(
         tracks: rideViewModel.radarTracks,
         isDimmed: rideViewModel.isRadarDimmed,
         isConnected: rideViewModel.isRadarConnected,
         unitSystem: rideViewModel.unitSystem,
         style: .column,
         onTap: onShowRadarPage
      )
   }

   // MARK: - Landscape

   /// Three columns: the map with its status and controls, the hero with its
   /// two cards, and the road running the full height. The road still takes
   /// the rider's side.
   private var landscape: some View {
      HStack(alignment: .top, spacing: 12) {
         if roadLeads {
            road.frame(width: 150)
         }

         VStack(spacing: 8) {
            RideDashboardStatusRow(
               rideViewModel: rideViewModel,
               onShowRadar: onShowRadar
            )

            if routeGuidanceViewModel.isActive {
               RouteGuidanceStripView(
                  routeGuidanceViewModel: routeGuidanceViewModel,
                  rideMapViewModel: rideMapViewModel
               )
            }

            RideMapDrawer(
               rideMapViewModel: rideMapViewModel,
               isMapMounted: showsDrawerMap,
               isVertical: false,
               onExpand: onExpandMap,
               isOpen: $isDrawerOpen
            )
            .overlay(alignment: .bottomTrailing) {
               RideControlBar(rideViewModel: rideViewModel, style: .compact)
                  .padding(.trailing, 10)
                  .padding(.bottom, 10)
            }
            .frame(maxHeight: .infinity)
            .layoutPriority(-1)
         }
         .frame(maxWidth: .infinity, maxHeight: .infinity)

         VStack(spacing: 8) {
            RideDashboardInstrumentHero(
               rideViewModel: rideViewModel,
               isExpanded: false,
               layout: .landscape
            )
            .layoutPriority(1)

            trafficCards(isCompact: true)
         }
         .frame(maxWidth: 300)
         .contentShape(.rect)
         .simultaneousGesture(swipeForward)

         if !roadLeads {
            road.frame(width: 150)
         }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .safeAreaPadding(.leading, 8)
      .safeAreaPadding(.trailing, 8)
   }

   // MARK: - Cards

   /// The Traffic page's own two slots, stacked. Both are protected by
   /// default, so a long press here offers the swap and nothing else — the
   /// two cards trade places, and neither can be taken away.
   private func trafficCards(isCompact: Bool) -> some View {
      let readouts = RideCockpitMetricReadouts(
         rideViewModel: rideViewModel,
         rideClimbModel: rideClimbModel,
         routeGuidanceViewModel: routeGuidanceViewModel
      )
      let tiles = readouts.visibleTiles(rideViewModel.cockpitLayout.trafficTiles)

      return VStack(spacing: isCompact ? 8 : 10) {
         ForEach(tiles) { metric in
            let readout = readouts.readout(for: metric)

            RideMetricTile(
               title: metric.title,
               value: readout?.value ?? RideFormatters.placeholder,
               unit: readout?.unit,
               identifier: "ride.traffic." + metric.rawValue,
               isCompact: isCompact,
               onLongPress: { rideViewModel.requestMetricSwap(metric, on: .traffic) }
            )
         }
      }
      .animation(.easeInOut(duration: 0.25), value: tiles)
   }

   // MARK: - Page Swipe

   private var swipeForward: some Gesture {
      DragGesture(minimumDistance: RidePageSwipe.minimumDistance)
         .onEnded { value in
            guard RidePageSwipe.isForward(value) else { return }
            onSwipeForward()
         }
   }
}

#Preview("Portrait") {
   ZStack {
      RideAtmosphereBackground()
      RideTrafficPageView(
         rideViewModel: RideViewModel(),
         rideMapViewModel: RideMapViewModel(),
         routeGuidanceViewModel: RouteGuidanceViewModel(),
         onExpandMap: {},
         onShowRadar: {},
         onShowRadarPage: {}
      )
   }
   .environment(RideWeatherModel(unitsSettings: RideUnitsSettings()))
   .environment(RideClimbModel())
   .environment(RideBackToStartModel())
   .environment(RideAppearanceSettings())
   .preferredColorScheme(.dark)
}

#Preview("Landscape", traits: .landscapeLeft) {
   ZStack {
      RideAtmosphereBackground()
      RideTrafficPageView(
         rideViewModel: RideViewModel(),
         rideMapViewModel: RideMapViewModel(),
         routeGuidanceViewModel: RouteGuidanceViewModel(),
         onExpandMap: {},
         onShowRadar: {},
         onShowRadarPage: {}
      )
   }
   .environment(RideWeatherModel(unitsSettings: RideUnitsSettings()))
   .environment(RideClimbModel())
   .environment(RideBackToStartModel())
   .environment(RideAppearanceSettings())
   .preferredColorScheme(.dark)
}
