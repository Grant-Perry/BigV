//
//  RideDashboardLandscapeView.swift
//  BigV
//

import SwiftUI

/// Landscape cockpit: same three panes as before, content rotated.
///
/// The leading pane stays the large cluster slot — the map lives there now.
/// Trailing top is the old metrics slot (speed). Trailing bottom is the old
/// map slot (tiles). Frames are unchanged; only the children swapped.
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
            ZStack {
               RideDashboardMetricsGrid(
                  rideViewModel: rideViewModel,
                  routeGuidanceViewModel: routeGuidanceViewModel,
                  layout: .landscape
               )
               .hidden()
               .accessibilityHidden(true)

               RideDashboardInstrumentHero(
                  rideViewModel: rideViewModel,
                  isExpanded: false,
                  layout: .landscape
               )
            }
            .layoutPriority(1)

            RideDashboardMetricsGrid(
               rideViewModel: rideViewModel,
               routeGuidanceViewModel: routeGuidanceViewModel,
               layout: .landscape
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .frame(minHeight: isDrawerOpen ? 96 : RideMapDrawer.collapsedHeight)
            .clipped()
            .layoutPriority(-1)
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
