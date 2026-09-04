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
   let onShowRadar: () -> Void

   @Environment(RideClimbModel.self) private var rideClimbModel
   @State private var selectedPage: RidePage = .dashboard
   @State private var isMapPageMounted = false

   /// The radar page exists only when a radar does — no rider without one
   /// should ever swipe onto an empty road. The climb page is always present:
   /// freeride still detects climbs, and an empty page teaches the swipe.
   ///
   /// Filtered rather than listed, so `RidePage`'s declaration order stays the
   /// single place swipe order is decided.
   private var pages: [RidePage] {
      RidePage.allCases.filter { $0 != .radar || rideViewModel.isRadarAvailable }
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

         bottomStrip
      }
      .background(Color.clear)
      .onChange(of: selectedPage) { _, page in
         if page == .map { isMapPageMounted = true }
         routeGuidanceViewModel.collapseTurnList()
      }
      .onChange(of: pages) { _, available in
         // A radar that appears or disappears mid-ride reorders the deck under
         // the rider; keep them on the page they were reading.
         guard !available.contains(selectedPage) else { return }
         selectedPage = .dashboard
      }
      // A categorized climb starting pulls the dashboard onto the climb page.
      // Only the dashboard: a rider reading the map or the radar chose to.
      .onChange(of: rideClimbModel.climbStartPulse) { _, _ in
         guard rideClimbModel.isAutoSwitchEnabled, selectedPage == .dashboard else { return }
         withAnimation { selectedPage = .climb }
      }
   }

   // MARK: - Bottom Strip

   /// Page dots and the attribution whisper share one band above the tab bar.
   /// Stacking them as two separate rows would cost the speed hero another
   /// twenty points for no extra information.
   private var bottomStrip: some View {
      VStack(spacing: 4) {
         RidePageIndicatorView(pages: pages, selectedPage: selectedPage)

         RideAppFooterView(style: .compact)
      }
      .padding(.top, 6)
      .padding(.bottom, 2)
   }

   // MARK: - Page Swipe

   /// Moves one page along the deck, stopping at either end.
   private func turnPage(by offset: Int) {
      guard let index = pages.firstIndex(of: selectedPage) else { return }

      let destination = index + offset
      guard pages.indices.contains(destination) else { return }

      selectedPage = pages[destination]
   }

   /// The map page pans everywhere now, so a drag anywhere in it is a pan and
   /// nothing else. Only the leading edge still turns a page — the same corner
   /// of the screen every iOS back gesture lives in — and the collapse button in
   /// the overlay is the way out that needs no gesture at all.
   private var swipeOffMap: some Gesture {
      DragGesture(minimumDistance: RidePageSwipe.minimumDistance)
         .onEnded { value in
            guard RidePageSwipe.isBack(value),
                  RidePageSwipe.startsAtLeadingEdge(value)
            else { return }

            turnPage(by: -1)
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
               onExpandMap: { selectedPage = .map },
               onShowRadar: onShowRadar,
               onSwipeForward: { turnPage(by: 1) }
            )

         case .climb:
            RideClimbPageView()

         case .map:
            Group {
               if isMapPageMounted {
                  RideMapView(
                     rideViewModel: rideViewModel,
                     rideMapViewModel: rideMapViewModel,
                     routeGuidanceViewModel: routeGuidanceViewModel,
                     onCollapse: { selectedPage = .dashboard }
                  )
               } else {
                  Color.clear
               }
            }
            .simultaneousGesture(swipeOffMap)

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
               .fill(page == selectedPage ? RideDashboardTheme.ice.opacity(0.9) : RideDashboardTheme.ink(0.22))
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
      onShowRadar: {}
   )
   .environment(RideWeatherModel(unitsSettings: RideUnitsSettings()))
   .environment(RideClimbModel())
   .environment(RideBackToStartModel())
   .environment(RideAppearanceSettings())
   .preferredColorScheme(.dark)
}
