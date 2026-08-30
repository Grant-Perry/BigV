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

            // The tape lies over the hero rather than taking a column of its
            // own: landscape has no width to spare, and the hero is the one
            // surface with nothing in its margins to cover.
            RideDashboardInstrumentHero(
               rideViewModel: rideViewModel,
               isExpanded: !isDrawerOpen
            )
            .frame(maxHeight: .infinity)
            .layoutPriority(-1)
            .rideRadarTape(
               placement: rideViewModel.radarPlacement,
               tracks: rideViewModel.radarTracks,
               isVisible: rideViewModel.showsRadarTape,
               isDimmed: rideViewModel.isRadarDimmed,
               unitSystem: rideViewModel.unitSystem,
               thickness: compactTapeThickness,
               inset: 6
            )

            RideDashboardLiveMetricSection(rideViewModel: rideViewModel)
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
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .safeAreaPadding(.leading, 8)
      .safeAreaPadding(.trailing, 8)
   }

   // MARK: - Radar

   private var compactTapeThickness: CGFloat {
      rideViewModel.radarPlacement.isVertical
         ? RideRadarTapeView.compactWidth
         : RideRadarTapeView.barThickness
   }
}
