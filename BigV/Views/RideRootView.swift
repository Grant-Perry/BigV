//
//  RideRootView.swift
//  BigV
//

import SwiftUI

/// The app's tab bar and the four places it leads.
///
/// Nothing here is modal except radar pairing, which is hardware setup reached
/// from two places rather than a destination of its own.
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
   @State private var selectedTab: RideTab = .dashboard
   @State private var isShowingRadarPairing = false

   var body: some View {
      TabView(selection: $selectedTab) {
         Tab(RideTab.dashboard.title, systemImage: RideTab.dashboard.symbolName, value: .dashboard) {
            RideCockpitView(
               rideViewModel: rideViewModel,
               rideMapViewModel: rideMapViewModel,
               routeGuidanceViewModel: routeGuidanceViewModel,
               summaryRouteViewModel: summaryRouteViewModel,
               onShowRadar: { isShowingRadarPairing = true }
            )
         }

         Tab(RideTab.rides.title, systemImage: RideTab.rides.symbolName, value: .rides) {
            RideHistoryView(
               rideHistoryViewModel: rideHistoryViewModel,
               rideRouteViewModel: historyRouteViewModel
            )
         }

         Tab(RideTab.route.title, systemImage: RideTab.route.symbolName, value: .route) {
            RoutePlannerView(routePlannerViewModel: routePlannerViewModel) {
               selectedTab = .dashboard
            }
         }

         Tab(RideTab.settings.title, systemImage: RideTab.settings.symbolName, value: .settings) {
            RideSettingsView(
               unitsSettings: rideUnitsSettings,
               onShowRadar: { isShowingRadarPairing = true },
               onFinishSetup: { selectedTab = .dashboard }
            )
         }
      }
      .overlay {
         // The threat tint sits above every tab: peripheral colour has to work
         // no matter what the rider is looking at.
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
      .sheet(isPresented: $isShowingRadarPairing) {
         RideRadarPairingView(pairingViewModel: rideRadarPairingViewModel)
      }
      .onChange(of: scenePhase) { _, newPhase in
         guard newPhase != .active else { return }
         rideViewModel.flushPendingWork()
      }
      // A ride can start or end from the wrist while the rider is reading
      // history, so the cockpit comes to them rather than waiting to be found.
      .onChange(of: rideViewModel.isRecording) { _, isRecording in
         if isRecording { selectedTab = .dashboard }
      }
      .onChange(of: rideViewModel.isFinished) { _, isFinished in
         if isFinished { selectedTab = .dashboard }
      }
      .task {
         // First launch lands on settings so units are chosen once; after that
         // the tab bar is the way back in.
         if !rideUnitsSettings.hasCompletedSetup {
            selectedTab = .settings
         }
      }
   }
}
