//
//  RoutePlannerSheet.swift
//  BigV
//

import SwiftUI

/// Plan a ride to somewhere: search, then look at what Apple offers, then commit.
///
/// Presented as a sheet from the map page while idle, so nothing here ever sits
/// between the rider and their live numbers.
struct RoutePlannerSheet: View {

   let routePlannerViewModel: RoutePlannerViewModel

   @Environment(\.dismiss) private var dismiss

   var body: some View {
      NavigationStack {
         stage
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
               RideAtmosphereBackground(scene: .rideTo)
                  .ignoresSafeArea()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbar {
               ToolbarItem(placement: .topBarLeading) {
                  Button("Close") { dismiss() }
                     .accessibilityIdentifier("planner.button.close")
               }

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
            RoutePreviewStageView(routePlannerViewModel: routePlannerViewModel) {
               dismiss()
            }
      }
   }

   private var planning: some View {
      VStack(spacing: 12) {
         ProgressView()
            .tint(.white.opacity(0.7))

         Text("Finding a bike route…")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.6))
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
   RoutePlannerSheet(routePlannerViewModel: RoutePlannerViewModel())
      .preferredColorScheme(.dark)
}
