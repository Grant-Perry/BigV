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
