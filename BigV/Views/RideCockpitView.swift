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
   let summaryDetailViewModel: RideDetailViewModel
   let onShowRadar: () -> Void

   /// Shown for a few seconds after the app picks a ride back up. The rider was
   /// somewhere else when iOS took the app away, so the first thing they need
   /// to know on returning is that their ride is still running.
   @State private var isShowingRecoveryNotice = false

   /// The pulse this cockpit has already announced, so leaving the tab and
   /// coming back does not re-announce a recovery from an hour ago.
   @State private var acknowledgedRecoveryPulse = 0

   var body: some View {
      Group {
         if rideViewModel.isFinished {
            RideSummaryView(
               rideViewModel: rideViewModel,
               rideRouteViewModel: summaryRouteViewModel,
               rideDetailViewModel: summaryDetailViewModel
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
         VStack(spacing: 6) {
            if rideViewModel.showsAccessLock {
               accessLockBanner
            }

            if isShowingRecoveryNotice {
               recoveryBanner
            }
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
      // Recovery runs before any view exists, so the pulse is already set by the
      // time this appears — hence `task` as well as `onChange`.
      .task { showRecoveryNoticeIfNeeded() }
      .onChange(of: rideViewModel.recoveredRidePulse) { _, _ in
         showRecoveryNoticeIfNeeded()
      }
   }

   // MARK: - Recovery Notice

   private func showRecoveryNoticeIfNeeded() {
      let pulse = rideViewModel.recoveredRidePulse
      guard pulse > 0, pulse != acknowledgedRecoveryPulse else { return }

      acknowledgedRecoveryPulse = pulse
      withAnimation { isShowingRecoveryNotice = true }

      Task {
         try? await Task.sleep(for: .seconds(6))
         withAnimation { isShowingRecoveryNotice = false }
      }
   }

   private var recoveryBanner: some View {
      HStack(spacing: 8) {
         Image(systemName: "arrow.clockwise.circle.fill")
            .font(.footnote.weight(.bold))

         Text("Ride restored — still recording from where you left off.")
            .font(.caption.weight(.semibold))
            .multilineTextAlignment(.leading)
      }
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(RideDashboardTheme.go.opacity(0.88), in: .rect(cornerRadius: 12))
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .transition(.opacity.combined(with: .move(edge: .top)))
      .accessibilityIdentifier("dashboard.banner.rideRestored")
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
      summaryDetailViewModel: RideDetailViewModel(),
      onShowRadar: {}
   )
   .environment(RideWeatherModel(unitsSettings: RideUnitsSettings()))
   .environment(RideClimbModel())
   .environment(RideBackToStartModel())
   .environment(RideAppearanceSettings())
   .preferredColorScheme(.dark)
}
