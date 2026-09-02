//
//  RideDashboardView.swift
//  BigV
//

import SwiftUI

/// The primary bike-computer screen, with a live map drawer on the dashboard.
struct RideDashboardView: View {

   let rideViewModel: RideViewModel
   let rideMapViewModel: RideMapViewModel
   let routeGuidanceViewModel: RouteGuidanceViewModel
   var showsDrawerMap: Bool = true
   let onExpandMap: () -> Void
   let onShowRadar: () -> Void

   @Environment(\.verticalSizeClass) private var verticalSizeClass
   @Environment(\.scenePhase) private var scenePhase
   @State private var isDrawerOpen = true

   var body: some View {
      Group {
         if verticalSizeClass == .compact {
            RideDashboardLandscapeView(
               rideViewModel: rideViewModel,
               rideMapViewModel: rideMapViewModel,
               routeGuidanceViewModel: routeGuidanceViewModel,
               showsDrawerMap: showsDrawerMap,
               onExpandMap: onExpandMap,
               onShowRadar: onShowRadar,
               isDrawerOpen: $isDrawerOpen
            )
         } else {
            portrait
         }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      // The magnetometer only matters while this screen is up: it is what
      // gives the ribbon a heading at a standstill, and it costs battery, so
      // it runs exactly as long as the cockpit is on screen and in front.
      .onAppear { rideViewModel.startCompassHeading() }
      .onDisappear { rideViewModel.stopCompassHeading() }
      .onChange(of: scenePhase) { _, phase in
         if phase == .active {
            rideViewModel.startCompassHeading()
         } else {
            rideViewModel.stopCompassHeading()
         }
      }
   }

   // MARK: - Portrait

   private var portrait: some View {
      VStack(spacing: 10) {
         upperColumn

         RideMapDrawer(
            rideMapViewModel: rideMapViewModel,
            isMapMounted: showsDrawerMap,
            onExpand: onExpandMap,
            isOpen: $isDrawerOpen
         )
         .overlay(alignment: .bottom) {
            RideControlBar(rideViewModel: rideViewModel)
               .padding(.bottom, 10)
         }
         // A bottom tape parks on the drawer's top edge rather than the true
         // bottom of the cockpit: the metrics grid ends flush against the
         // drawer, so the natural edge would lie across the speed tiles, and
         // the true bottom belongs to START and END.
         .rideRadarTape(
            placement: rideViewModel.radarPlacement,
            tracks: rideViewModel.radarTracks,
            isVisible: rideViewModel.showsRadarTape && rideViewModel.radarPlacement == .bottom,
            isDimmed: rideViewModel.isRadarDimmed,
            unitSystem: rideViewModel.unitSystem,
            inset: 10,
            edgeInset: 8,
            alignment: .top,
            edge: .top
         )
         .layoutPriority(1)
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 6)
   }

   /// Everything above the map drawer — status, guidance, hero, metrics.
   private var upperColumn: some View {
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

         instrumentStack
      }
   }

   /// The hero, the compass band and the strip: the surface the radar tape
   /// lies over.
   ///
   /// Scoped to these rather than the whole column so the tape can never cover
   /// the status chips at the top or the drawer's controls below, whichever
   /// edge the rider parks it on. The cards already hold their content away
   /// from the left and right margins, so a vertical tape lands on empty card.
   ///
   /// Top to bottom is the reading order on a bike: speed with the heading
   /// under it, then how far and how long, then the climb figures.
   private var instrumentStack: some View {
      VStack(spacing: 10) {
         RideDashboardInstrumentHero(
            rideViewModel: rideViewModel,
            isExpanded: !isDrawerOpen
         )
         .frame(maxHeight: .infinity)
         .layoutPriority(-1)

         RideDashboardLiveMetricSection(rideViewModel: rideViewModel)
            .layoutPriority(0)

         RideDashboardMetricsGrid(
            rideViewModel: rideViewModel,
            routeGuidanceViewModel: routeGuidanceViewModel
         )
         .layoutPriority(1)
      }
      .rideRadarTape(
         placement: rideViewModel.radarPlacement,
         tracks: rideViewModel.radarTracks,
         isVisible: rideViewModel.showsRadarTape && rideViewModel.radarPlacement != .bottom,
         isDimmed: rideViewModel.isRadarDimmed,
         unitSystem: rideViewModel.unitSystem
      )
   }
}

#Preview("Portrait") {
   ZStack {
      RideAtmosphereBackground()
      RideDashboardView(
         rideViewModel: RideViewModel(),
         rideMapViewModel: RideMapViewModel(),
         routeGuidanceViewModel: RouteGuidanceViewModel(),
         onExpandMap: {},
         onShowRadar: {}
      )
   }
   .environment(RideWeatherModel(unitsSettings: RideUnitsSettings()))
   .environment(RideClimbModel())
   .environment(RideBackToStartModel())
   .preferredColorScheme(.dark)
}

#Preview("Landscape", traits: .landscapeLeft) {
   ZStack {
      RideAtmosphereBackground()
      RideDashboardView(
         rideViewModel: RideViewModel(),
         rideMapViewModel: RideMapViewModel(),
         routeGuidanceViewModel: RouteGuidanceViewModel(),
         onExpandMap: {},
         onShowRadar: {}
      )
   }
   .environment(RideWeatherModel(unitsSettings: RideUnitsSettings()))
   .environment(RideClimbModel())
   .environment(RideBackToStartModel())
   .preferredColorScheme(.dark)
}
