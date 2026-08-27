//
//  RideRootView.swift
//  BigV
//

import SwiftUI

/// Switches between the live ride pages, the post-ride summary and history.
struct RideRootView: View {

   let rideViewModel: RideViewModel
   let rideMapViewModel: RideMapViewModel
   let rideHistoryViewModel: RideHistoryViewModel
   let summaryRouteViewModel: RideRouteViewModel
   let historyRouteViewModel: RideRouteViewModel
   let routePlannerViewModel: RoutePlannerViewModel
   let routeGuidanceViewModel: RouteGuidanceViewModel

   @Environment(\.scenePhase) private var scenePhase
   @State private var isShowingHistory = false
   @State private var isShowingRoutePlanner = false

   var body: some View {
      ZStack {
         RideAtmosphereBackground(scene: rideViewModel.isFinished ? .summary : .dashboard)
            .ignoresSafeArea()

         if rideViewModel.isFinished {
            RideSummaryView(
               rideViewModel: rideViewModel,
               rideRouteViewModel: summaryRouteViewModel
            )
         } else {
            RideLivePagerView(
               rideViewModel: rideViewModel,
               rideMapViewModel: rideMapViewModel,
               routeGuidanceViewModel: routeGuidanceViewModel,
               onShowHistory: { isShowingHistory = true },
               onPlanRoute: { isShowingRoutePlanner = true }
            )
         }
      }
      .preferredColorScheme(.dark)
      .sheet(isPresented: $isShowingHistory) {
         RideHistoryView(
            rideHistoryViewModel: rideHistoryViewModel,
            rideRouteViewModel: historyRouteViewModel
         )
         .preferredColorScheme(.dark)
      }
      .sheet(isPresented: $isShowingRoutePlanner) {
         RoutePlannerSheet(routePlannerViewModel: routePlannerViewModel)
            .preferredColorScheme(.dark)
      }
      .onChange(of: scenePhase) { _, newPhase in
         guard newPhase != .active else { return }
         rideViewModel.flushPendingWork()
      }
   }
}
