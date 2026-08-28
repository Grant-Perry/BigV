//
//  RideLivePagerView.swift
//  BigV
//

import SwiftUI

/// Swipeable pages of the live ride screen, dashboard first.
///
/// The dashboard drawer is the primary map. This page is the expanded map.
struct RideLivePagerView: View {

   let rideViewModel: RideViewModel
   let rideMapViewModel: RideMapViewModel
   let routeGuidanceViewModel: RouteGuidanceViewModel
   let onShowHistory: () -> Void
   let onPlanRoute: () -> Void
   let onShowRadar: () -> Void
   let onShowSetup: () -> Void

   @State private var selectedPage: RidePage = .dashboard
   @State private var isMapPageMounted = false

   /// The radar page exists only when a radar does — no rider without one
   /// should ever swipe onto an empty road.
   private var pages: [RidePage] {
      rideViewModel.isRadarAvailable ? RidePage.allCases : [.dashboard, .map]
   }

   var body: some View {
      VStack(spacing: 0) {
         TabView(selection: $selectedPage) {
            ForEach(pages) { ridePage in
               page(for: ridePage)
                  .tag(ridePage)
            }
         }
         .tabViewStyle(.page(indexDisplayMode: .never))

         RidePageIndicatorView(pages: pages, selectedPage: selectedPage)
            .padding(.vertical, 6)
      }
      .background(Color.clear)
      .onChange(of: selectedPage) { _, page in
         if page == .map { isMapPageMounted = true }
         routeGuidanceViewModel.collapseTurnList()
      }
      .onChange(of: rideViewModel.isRadarAvailable) { _, isAvailable in
         if !isAvailable, selectedPage == .radar {
            selectedPage = .dashboard
         }
      }
   }

   // MARK: - Page Swipe

   /// Drawer tap layers and MapKit pans can eat TabView's own drag. This
   /// recovers a clear horizontal swipe without disabling map zoom / explore pan.
   private var swipeToMap: some Gesture {
      DragGesture(minimumDistance: 40)
         .onEnded { value in
            guard RidePageSwipe.isForward(value) else { return }
            selectedPage = .map
         }
   }

   private var swipeToDashboard: some Gesture {
      DragGesture(minimumDistance: 40)
         .onEnded { value in
            if RidePageSwipe.isBack(value) {
               // Following: no map pan, so the whole page can page back.
               // Exploring: only a leading-edge swipe, so a map pan stays a pan.
               if rideMapViewModel.isFollowingRider || RidePageSwipe.startsAtLeadingEdge(value) {
                  selectedPage = .dashboard
               }
               return
            }

            // Forward off the map lands on the radar page, when one exists.
            if RidePageSwipe.isForward(value),
               rideMapViewModel.isFollowingRider,
               pages.contains(.radar) {
               selectedPage = .radar
            }
         }
   }

   // MARK: - Pages

   @ViewBuilder
   private func page(for ridePage: RidePage) -> some View {
      switch ridePage {
         case .dashboard:
            RideDashboardView(
               rideViewModel: rideViewModel,
               rideMapViewModel: rideMapViewModel,
               routeGuidanceViewModel: routeGuidanceViewModel,
               showsDrawerMap: selectedPage == .dashboard,
               onShowHistory: onShowHistory,
               onPlanRoute: onPlanRoute,
               onExpandMap: { selectedPage = .map },
               onShowRadar: onShowRadar,
               onShowSetup: onShowSetup
            )
            .simultaneousGesture(swipeToMap)

         case .map:
            Group {
               if isMapPageMounted {
                  RideMapView(
                     rideViewModel: rideViewModel,
                     rideMapViewModel: rideMapViewModel,
                     routeGuidanceViewModel: routeGuidanceViewModel,
                     onPlanRoute: onPlanRoute
                  )
               } else {
                  Color.clear
               }
            }
            .simultaneousGesture(swipeToDashboard)

         case .radar:
            RideRadarPageView(
               rideViewModel: rideViewModel,
               onShowRadar: onShowRadar
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
               .fill(page == selectedPage ? RideDashboardTheme.ice.opacity(0.9) : .white.opacity(0.22))
               .frame(width: page == selectedPage ? 18 : 6, height: 6)
         }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Page \(selectedPage.title)")
   }
}

// MARK: - Swipe Test

private enum RidePageSwipe {

   static func isForward(_ value: DragGesture.Value) -> Bool {
      isHorizontal(value) && value.translation.width < -60
   }

   static func isBack(_ value: DragGesture.Value) -> Bool {
      isHorizontal(value) && value.translation.width > 60
   }

   static func startsAtLeadingEdge(_ value: DragGesture.Value) -> Bool {
      value.startLocation.x < 36
   }

   private static func isHorizontal(_ value: DragGesture.Value) -> Bool {
      abs(value.translation.width) > abs(value.translation.height) * 1.3
   }
}

#Preview {
   RideLivePagerView(
      rideViewModel: RideViewModel(),
      rideMapViewModel: RideMapViewModel(),
      routeGuidanceViewModel: RouteGuidanceViewModel(),
      onShowHistory: {},
      onPlanRoute: {},
      onShowRadar: {},
      onShowSetup: {}
   )
   .preferredColorScheme(.dark)
}
