//
//  RideCockpitView.swift
//  BigV
//

import SwiftUI

/// The dashboard tab: live cockpit pages until the ride is done, then totals.
///
/// The tab bar owns everything else in the app, so this view's only job is to
/// pick between riding and having ridden, on the right scene art.
struct RideCockpitView: View {

   let rideViewModel: RideViewModel
   let rideMapViewModel: RideMapViewModel
   let routeGuidanceViewModel: RouteGuidanceViewModel
   let summaryRouteViewModel: RideRouteViewModel
   let rideDetailViewModel: RideDetailViewModel
   let onShowRadar: () -> Void

   var body: some View {
      Group {
         if rideViewModel.isFinished {
            RideSummaryView(
               rideViewModel: rideViewModel,
               rideRouteViewModel: summaryRouteViewModel,
               rideDetailViewModel: rideDetailViewModel
            )
            .rideAppFooter()
         } else {
            RideLivePagerView(
               rideViewModel: rideViewModel,
               rideMapViewModel: rideMapViewModel,
               routeGuidanceViewModel: routeGuidanceViewModel,
               onShowRadar: onShowRadar
            )
         }
      }
      // A background rather than a ZStack sibling: a full-bleed layer inside a
      // stack inflates the stack past the safe area, which pushes the status
      // row under the notch and clips the drawer behind the tab bar.
      .background {
         RideAtmosphereBackground(scene: rideViewModel.isFinished ? .summary : .dashboard)
            .ignoresSafeArea()
      }
      .safeAreaInset(edge: .top, spacing: 0) {
         if rideViewModel.showsAccessLock {
            accessLockBanner
         }
      }
      .sheet(isPresented: accessPaywallBinding) {
         if let plusStore = rideViewModel.plusStore {
            RideAccessPaywallView(plusStore: plusStore) {
               rideViewModel.isShowingAccessPaywall = false
            }
            .presentationDetents([.medium, .large])
         }
      }
      .onChange(of: rideViewModel.startDeniedPulse) { _, _ in
         rideViewModel.presentAccessPaywallIfLocked()
      }
   }

   private var accessPaywallBinding: Binding<Bool> {
      Binding(
         get: { rideViewModel.isShowingAccessPaywall },
         set: { rideViewModel.isShowingAccessPaywall = $0 }
      )
   }

   private var accessLockBanner: some View {
      Button {
         rideViewModel.presentAccessPaywallIfLocked()
      } label: {
         Text("Trial ended — view and export rides, or keep BigVelo to ride again.")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RideDashboardTheme.ember.opacity(0.88), in: .rect(cornerRadius: 12))
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .accessibilityIdentifier("dashboard.banner.accessLock")
   }
}

#Preview {
   RideCockpitView(
      rideViewModel: RideViewModel(),
      rideMapViewModel: RideMapViewModel(),
      routeGuidanceViewModel: RouteGuidanceViewModel(),
      summaryRouteViewModel: RideRouteViewModel(),
      rideDetailViewModel: RideDetailViewModel(),
      onShowRadar: {}
   )
   .environment(RideWeatherModel(unitsSettings: RideUnitsSettings()))
   .environment(RideClimbModel())
   .environment(RideBackToStartModel())
   .environment(RideAppearanceSettings())
   .preferredColorScheme(.dark)
}
