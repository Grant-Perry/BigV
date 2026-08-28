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
   let onShowHistory: () -> Void
   let onPlanRoute: () -> Void
   let onExpandMap: () -> Void
   let onShowRadar: () -> Void
   let onShowSetup: () -> Void

   @Environment(\.verticalSizeClass) private var verticalSizeClass
   @State private var isDrawerOpen = true

   var body: some View {
      Group {
         if verticalSizeClass == .compact {
            RideDashboardLandscapeView(
               rideViewModel: rideViewModel,
               rideMapViewModel: rideMapViewModel,
               routeGuidanceViewModel: routeGuidanceViewModel,
               showsDrawerMap: showsDrawerMap,
               onShowHistory: onShowHistory,
               onPlanRoute: onPlanRoute,
               onExpandMap: onExpandMap,
               onShowRadar: onShowRadar,
               onShowSetup: onShowSetup,
               isDrawerOpen: $isDrawerOpen
            )
         } else {
            portrait
         }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
   }

   // MARK: - Portrait

   private var portrait: some View {
      VStack(spacing: 10) {
         upperColumn

         RideMapDrawer(
            rideMapViewModel: rideMapViewModel,
            isMapMounted: showsDrawerMap,
            onExpand: onExpandMap,
            onPlanRoute: onPlanRoute,
            isOpen: $isDrawerOpen
         )
         .overlay(alignment: .bottom) {
            RideControlBar(rideViewModel: rideViewModel)
               .padding(.bottom, 10)
         }
         .layoutPriority(1)
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 6)
   }

   /// Everything above the map drawer — status, guidance, hero, metrics.
   /// The radar ribbon rides this whole column's tall edge in a reserved
   /// gutter, so it spans from the top of the dashboard down to just above
   /// the drawer without colliding with tiles or buttons.
   private var upperColumn: some View {
      VStack(spacing: 10) {
         RideDashboardStatusRow(
            rideViewModel: rideViewModel,
            onShowHistory: onShowHistory,
            onPlanRoute: onPlanRoute,
            onShowRadar: onShowRadar,
            onShowSetup: onShowSetup
         )

         if routeGuidanceViewModel.isActive {
            RouteGuidanceStripView(
               routeGuidanceViewModel: routeGuidanceViewModel,
               rideMapViewModel: rideMapViewModel
            )
         }

         RideSpeedHeroView(
            value: rideViewModel.speed,
            unit: rideViewModel.speedUnit,
            course: rideViewModel.course,
            heading: rideViewModel.heading,
            headingDegrees: rideViewModel.headingDegrees,
            isDimmed: !rideViewModel.hasGPSFix || rideViewModel.isPaused,
            isExpanded: !isDrawerOpen
         )
         .frame(maxHeight: .infinity)
         .layoutPriority(-1)

         RideDashboardMetricsGrid(
            rideViewModel: rideViewModel,
            routeGuidanceViewModel: routeGuidanceViewModel
         )
         .layoutPriority(1)
      }
      .padding(
         rideViewModel.radarSide.paddingEdge,
         rideViewModel.showsRadarTape ? Self.radarGutterWidth : 0
      )
      .overlay(alignment: rideViewModel.radarSide.overlayAlignment) {
         if rideViewModel.showsRadarTape {
            RideRadarTapeView(
               tracks: rideViewModel.radarTracks,
               isDimmed: rideViewModel.isRadarDimmed,
               unitSystem: rideViewModel.unitSystem,
               tapeWidth: RideRadarTapeView.dashboardWidth
            )
            .padding(.vertical, 2)
            .transition(.move(edge: rideViewModel.radarSide.transitionEdge).combined(with: .opacity))
         }
      }
      // The gutter opening and closing is a full-width reflow of the cockpit,
      // so it slides rather than snapping when a radar drops or reconnects.
      .animation(.smooth(duration: 0.3), value: rideViewModel.showsRadarTape)
   }

   /// Content inset on the radar side: the tape's width plus a small gap.
   private static let radarGutterWidth: CGFloat = RideRadarTapeView.dashboardWidth + 8
}

#Preview("Portrait") {
   ZStack {
      RideAtmosphereBackground()
      RideDashboardView(
         rideViewModel: RideViewModel(),
         rideMapViewModel: RideMapViewModel(),
         routeGuidanceViewModel: RouteGuidanceViewModel(),
         onShowHistory: {},
         onPlanRoute: {},
         onExpandMap: {},
         onShowRadar: {},
         onShowSetup: {}
      )
   }
   .preferredColorScheme(.dark)
}

#Preview("Landscape", traits: .landscapeLeft) {
   ZStack {
      RideAtmosphereBackground()
      RideDashboardView(
         rideViewModel: RideViewModel(),
         rideMapViewModel: RideMapViewModel(),
         routeGuidanceViewModel: RouteGuidanceViewModel(),
         onShowHistory: {},
         onPlanRoute: {},
         onExpandMap: {},
         onShowRadar: {},
         onShowSetup: {}
      )
   }
   .preferredColorScheme(.dark)
}
