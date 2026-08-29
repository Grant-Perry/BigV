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
   let onExpandMap: () -> Void
   let onShowRadar: () -> Void

   @Binding var isDrawerOpen: Bool

   var body: some View {
      HStack(alignment: .top, spacing: 12) {
         // Landscape has the width to give the radar its own column, so the
         // tape spans the full cockpit height instead of hugging the hero.
         if rideViewModel.showsRadarTape, rideViewModel.radarSide == .leading {
            radarColumn
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
               routeGuidanceViewModel: routeGuidanceViewModel,
               isCompact: true
            )

            RideMapDrawer(
               rideMapViewModel: rideMapViewModel,
               isMapMounted: showsDrawerMap,
               isVertical: false,
               onExpand: onExpandMap,
               isOpen: $isDrawerOpen
            )
            .overlay(alignment: .bottom) {
               RideControlBar(rideViewModel: rideViewModel)
                  .padding(.bottom, 10)
            }
            .frame(minHeight: isDrawerOpen ? 96 : RideMapDrawer.collapsedHeight)
         }
         .frame(maxWidth: 340)

         if rideViewModel.showsRadarTape, rideViewModel.radarSide == .trailing {
            radarColumn
         }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .safeAreaPadding(.leading, 8)
      .safeAreaPadding(.trailing, 8)
   }

   // MARK: - Radar

   private var radarColumn: some View {
      RideRadarTapeView(
         tracks: rideViewModel.radarTracks,
         isDimmed: rideViewModel.isRadarDimmed,
         unitSystem: rideViewModel.unitSystem
      )
      .padding(.vertical, 4)
   }
}
