//
//  RoutePlannerView.swift
//  BigV
//

import SwiftUI

/// The Route tab: type a destination, look at what Apple offers, then commit.
///
/// A tab rather than a sheet, so planning a route is somewhere the rider goes
/// instead of something that covers the cockpit. Following a route hands them
/// straight back to the dashboard, which is where the line is actually drawn.
struct RoutePlannerView: View {

   let routePlannerViewModel: RoutePlannerViewModel

   /// Called once a route is being followed, so the tab bar can move on.
   let onFollowRoute: () -> Void

   var body: some View {
      NavigationStack {
         stage
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
               RideAtmosphereBackground(scene: .rideTo)
                  .ignoresSafeArea()
            }
            .rideAppFooter()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbar {
               ToolbarItem(placement: .topBarTrailing) {
                  if routePlannerViewModel.hasActiveRoute {
                     Button("Clear Route", role: .destructive) {
                        routePlannerViewModel.clearActiveRoute()
                     }
                     .accessibilityIdentifier("planner.button.clearRoute")
                  }
               }
            }
      }
      .onAppear { routePlannerViewModel.begin() }
      .onDisappear { routePlannerViewModel.end() }
   }

   // MARK: - Stages

   @ViewBuilder
   private var stage: some View {
      switch routePlannerViewModel.stage {
         case .search:
            RouteSearchStageView(routePlannerViewModel: routePlannerViewModel)

         case .planning:
            planning

         case .preview:
            RoutePreviewStageView(routePlannerViewModel: routePlannerViewModel, onConfirm: onFollowRoute)
      }
   }

   private var planning: some View {
      VStack(spacing: 12) {
         ProgressView()
            .tint(RideDashboardTheme.ink(0.7))

         Text("Finding a bike route…")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(RideDashboardTheme.ink(0.6))
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
   }

   // MARK: - Title

   private var title: String {
      switch routePlannerViewModel.stage {
         case .search: "Ride To"
         case .planning: "Planning"
         case .preview: routePlannerViewModel.destinationName
      }
   }
}

#Preview {
   RoutePlannerView(routePlannerViewModel: RoutePlannerViewModel(), onFollowRoute: {})
      .preferredColorScheme(.dark)
}
