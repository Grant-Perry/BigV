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
   let rideRadarPairingViewModel: RideRadarPairingViewModel
   let rideUnitsSettings: RideUnitsSettings

   @Environment(\.scenePhase) private var scenePhase
   @State private var isShowingHistory = false
   @State private var isShowingRoutePlanner = false
   @State private var isShowingRadarPairing = false
   @State private var isShowingSetup = false

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
               onPlanRoute: { isShowingRoutePlanner = true },
               onShowRadar: { isShowingRadarPairing = true },
               onShowSetup: { isShowingSetup = true }
            )
         }
      }
      .overlay {
         // The threat tint sits above every page: peripheral colour has to
         // work no matter what the rider is looking at.
         RideRadarAlertOverlay(
            tier: rideViewModel.radarTier,
            alertPulse: rideViewModel.radarAlertPulse,
            clearPulse: rideViewModel.radarClearPulse,
            isEnabled: rideViewModel.radarOverlayEnabled && rideViewModel.isRadarAvailable
         )
      }
      .sensoryFeedback(trigger: rideViewModel.radarAlertPulse) { _, _ in
         rideViewModel.radarAlertHapticsEnabled ? .impact(weight: .heavy) : nil
      }
      .sensoryFeedback(trigger: rideViewModel.radarClearPulse) { _, _ in
         rideViewModel.radarAlertHapticsEnabled ? .impact(weight: .light) : nil
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
      .sheet(isPresented: $isShowingRadarPairing) {
         RideRadarPairingView(pairingViewModel: rideRadarPairingViewModel)
      }
      .sheet(isPresented: $isShowingSetup) {
         RideSetupView(
            unitsSettings: rideUnitsSettings,
            onShowRadar: { isShowingRadarPairing = true }
         )
      }
      .onChange(of: scenePhase) { _, newPhase in
         guard newPhase != .active else { return }
         rideViewModel.flushPendingWork()
      }
      .task {
         // First launch walks through setup once; after that the gear on the
         // dashboard is the way back in.
         if !rideUnitsSettings.hasCompletedSetup {
            isShowingSetup = true
         }
      }
   }
}
