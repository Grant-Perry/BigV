//
//  RoutePreviewStageView.swift
//  BigV
//

import MapKit
import SwiftUI

/// The candidate routes on a map, with their numbers, so the rider can choose.
///
/// Apple exposes no "avoid busy streets" or "avoid hills" control to third
/// parties, so choosing between the alternates Apple ranked is the real decision
/// available here — which is why the distances, the times and any advisory sit
/// right next to the lines rather than behind a disclosure.
struct RoutePreviewStageView: View {

   let routePlannerViewModel: RoutePlannerViewModel
   let onConfirm: () -> Void

   @State private var favoriteBoomTrigger = 0

   var body: some View {
      VStack(spacing: 12) {
         map

         candidateList

         actions
      }
      .padding(.bottom, 14)
   }

   // MARK: - Map

   private var map: some View {
      Map(initialPosition: initialPosition, interactionModes: [.pan, .zoom]) {
         ForEach(routePlannerViewModel.candidates) { route in
            if !routePlannerViewModel.isSelected(route) {
               MapPolyline(coordinates: route.coordinates)
                  .stroke(PlannedRouteStyle.alternateLine, style: PlannedRouteStyle.alternateStroke)
            }
         }

         if let selected = routePlannerViewModel.selectedCandidate {
            MapPolyline(coordinates: selected.coordinates)
               .stroke(PlannedRouteStyle.line, style: PlannedRouteStyle.stroke)
         }

         if let destination = routePlannerViewModel.destination {
            Annotation(destination.name, coordinate: destination.coordinate, anchor: .center) {
               destinationMarker
            }
            .annotationTitles(.hidden)
         }

         UserAnnotation()
      }
      .mapStyle(.rideRoute)
      .frame(maxHeight: .infinity)
      .accessibilityLabel("Route preview map")
   }

   private var initialPosition: MapCameraPosition {
      guard let region = routePlannerViewModel.previewRegion else { return .automatic }
      return .region(region)
   }

   private var destinationMarker: some View {
      Circle()
         .fill(PlannedRouteStyle.destinationMarker)
         .stroke(.black, lineWidth: 2)
         .frame(width: 16, height: 16)
   }

   // MARK: - Candidates

   private var candidateList: some View {
      ScrollView(.vertical) {
         VStack(spacing: 8) {
            ForEach(Array(routePlannerViewModel.candidates.enumerated()), id: \.element.id) { index, route in
               Button {
                  routePlannerViewModel.selectCandidate(route.id)
               } label: {
                  RouteCandidateRowView(
                     title: routePlannerViewModel.title(forCandidateAt: index),
                     detail: routePlannerViewModel.detail(for: route),
                     distanceText: routePlannerViewModel.distanceText(for: route),
                     travelTimeText: routePlannerViewModel.travelTimeText(for: route),
                     advisories: route.advisories,
                     isSelected: routePlannerViewModel.isSelected(route),
                     climbSummary: routePlannerViewModel.climbSummaryText(for: route),
                     isLoadingElevation: routePlannerViewModel.isSelected(route)
                        && routePlannerViewModel.isEnrichingElevation
                  )
               }
               .buttonStyle(.plain)
               .accessibilityIdentifier("planner.candidate.\(index)")
            }

            // The chosen line's climbs, expandable to their profiles — the
            // vertical half of the decision the alternates ask the rider to make.
            if let selected = routePlannerViewModel.selectedCandidate,
               !selected.climbs.isEmpty {
               RouteClimbListView(route: selected)
            }
         }
         .padding(.horizontal, 16)
      }
      .scrollIndicators(.hidden)
      .frame(maxHeight: 250)
   }

   // MARK: - Actions

   private var actions: some View {
      VStack(spacing: 8) {
         HStack(spacing: 10) {
            Button("Back", role: .cancel) {
               routePlannerViewModel.cancelPreview()
            }
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.5))
            .accessibilityIdentifier("planner.button.back")

            Button {
               favoriteBoomTrigger += 1
               routePlannerViewModel.toggleSelectedRouteFavorite()
            } label: {
               StarBoomFavoriteStar(
                  isFavorite: routePlannerViewModel.isSelectedRouteFavorite,
                  boomTrigger: favoriteBoomTrigger
               )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
               routePlannerViewModel.isSelectedRouteFavorite ? "Remove favorite" : "Save favorite"
            )
            .accessibilityIdentifier("planner.button.favorite")

            Button {
               Task {
                  if await routePlannerViewModel.confirm() {
                     onConfirm()
                  }
               }
            } label: {
               if routePlannerViewModel.isPlanningApproach {
                  ProgressView()
                     .tint(.white)
               } else {
                  Text("Follow Route")
               }
            }
            .buttonStyle(.borderedProminent)
            .tint(RideDashboardTheme.ember)
            .disabled(!routePlannerViewModel.canConfirm)
            .accessibilityIdentifier("planner.button.follow")
         }
         .font(.headline)
         .controlSize(.large)

         if routePlannerViewModel.isPlanningApproach {
            Text("Getting you to the start…")
               .font(.caption.weight(.medium))
               .foregroundStyle(.white.opacity(0.55))
         }
      }
      .padding(.horizontal, 16)
   }
}

#Preview {
   ZStack {
      Color.black.ignoresSafeArea()
      RoutePreviewStageView(routePlannerViewModel: RoutePlannerViewModel()) {}
   }
   .preferredColorScheme(.dark)
}
