//
//  RideDashboardLandscapeView.swift
//  BigV
//

import SwiftUI

/// Landscape cockpit: speed stays fully on-screen, metrics and map sit trailing.
struct RideDashboardLandscapeView: View {

   let rideViewModel: RideViewModel
   let rideMapViewModel: RideMapViewModel
   let routeGuidanceViewModel: RouteGuidanceViewModel
   let showsDrawerMap: Bool
   let onShowHistory: () -> Void
   let onPlanRoute: () -> Void
   let onExpandMap: () -> Void

   @Binding var isDrawerOpen: Bool

   var body: some View {
      HStack(alignment: .top, spacing: 12) {
         VStack(spacing: 8) {
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
         }
         .frame(maxWidth: .infinity, maxHeight: .infinity)

         VStack(spacing: 8) {
            RideDashboardMetricsGrid(
               rideViewModel: rideViewModel,
               routeGuidanceViewModel: routeGuidanceViewModel
            )

            RideMapDrawer(
               rideMapViewModel: rideMapViewModel,
               isMapMounted: showsDrawerMap,
               isVertical: false,
               onExpand: onExpandMap,
               onPlanRoute: onPlanRoute,
               isOpen: $isDrawerOpen
            )
            .overlay(alignment: .bottom) {
               RideControlBar(rideViewModel: rideViewModel)
                  .padding(.bottom, 10)
            }
            .frame(minHeight: isDrawerOpen ? 120 : RideMapDrawer.collapsedHeight)
         }
         .frame(maxWidth: 340)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .safeAreaPadding(.leading, 8)
      .safeAreaPadding(.trailing, 8)
   }
}
