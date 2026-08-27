//
//  RideLivePagerView.swift
//  BigV
//

import SwiftUI

/// Swipeable pages of the live ride screen, dashboard first.
///
/// Adding a page means adding a `RidePage` case and a branch in `page(for:)`;
/// nothing else in the app needs to know the pager exists.
struct RideLivePagerView: View {

   let rideViewModel: RideViewModel
   let rideMapViewModel: RideMapViewModel
   let routeGuidanceViewModel: RouteGuidanceViewModel
   let onShowHistory: () -> Void
   let onPlanRoute: () -> Void

   @State private var selectedPage: RidePage = .dashboard

   var body: some View {
      VStack(spacing: 0) {
         TabView(selection: $selectedPage) {
            ForEach(RidePage.allCases) { ridePage in
               page(for: ridePage)
                  .tag(ridePage)
            }
         }
         .tabViewStyle(.page(indexDisplayMode: .never))

         RidePageIndicatorView(pages: RidePage.allCases, selectedPage: selectedPage)
            .padding(.vertical, 6)
      }
      .background(Color.black)
   }

   // MARK: - Pages

   @ViewBuilder
   private func page(for ridePage: RidePage) -> some View {
      switch ridePage {
         case .dashboard:
            RideDashboardView(
               rideViewModel: rideViewModel,
               routeGuidanceViewModel: routeGuidanceViewModel,
               onShowHistory: onShowHistory
            )

         case .map:
            RideMapView(
               rideMapViewModel: rideMapViewModel,
               routeGuidanceViewModel: routeGuidanceViewModel,
               onPlanRoute: onPlanRoute
            )
      }
   }
}

// MARK: - Indicator

/// Page dots drawn in-layout rather than overlaid, so they can never sit on top
/// of the control bar the rider is reaching for.
private struct RidePageIndicatorView: View {

   let pages: [RidePage]
   let selectedPage: RidePage

   var body: some View {
      HStack(spacing: 6) {
         ForEach(pages) { page in
            Capsule()
               .fill(.white.opacity(page == selectedPage ? 0.85 : 0.22))
               .frame(width: page == selectedPage ? 18 : 6, height: 6)
         }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Page \(selectedPage.title)")
   }
}

#Preview {
   RideLivePagerView(
      rideViewModel: RideViewModel(),
      rideMapViewModel: RideMapViewModel(),
      routeGuidanceViewModel: RouteGuidanceViewModel(),
      onShowHistory: {},
      onPlanRoute: {}
   )
   .preferredColorScheme(.dark)
}
