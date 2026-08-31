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
   .preferredColorScheme(.dark)
}
