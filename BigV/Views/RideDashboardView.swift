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
         RideDashboardStatusRow(
            rideViewModel: rideViewModel,
            onShowHistory: onShowHistory,
            onPlanRoute: onPlanRoute
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
            isDimmed: !rideViewModel.hasGPSFix || rideViewModel.isPaused,
            numeralSize: isDrawerOpen ? 84 : 108
         )
         .frame(maxHeight: .infinity)

         RideDashboardMetricsGrid(
            rideViewModel: rideViewModel,
            routeGuidanceViewModel: routeGuidanceViewModel
         )

         RideControlBar(rideViewModel: rideViewModel)

         RideMapDrawer(
            rideMapViewModel: rideMapViewModel,
            isMapMounted: showsDrawerMap,
            onExpand: onExpandMap,
            onPlanRoute: onPlanRoute,
            isOpen: $isDrawerOpen
         )
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 6)
   }
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
         onExpandMap: {}
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
         onExpandMap: {}
      )
   }
   .preferredColorScheme(.dark)
}
