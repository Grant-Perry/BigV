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
                     isSelected: routePlannerViewModel.isSelected(route)
                  )
               }
               .buttonStyle(.plain)
               .accessibilityIdentifier("planner.candidate.\(index)")
            }
         }
         .padding(.horizontal, 16)
      }
      .scrollIndicators(.hidden)
      .frame(maxHeight: 210)
   }

   // MARK: - Actions

   private var actions: some View {
      HStack(spacing: 10) {
         Button("Back", role: .cancel) {
            routePlannerViewModel.cancelPreview()
         }
         .buttonStyle(.bordered)
         .tint(.white.opacity(0.5))
         .accessibilityIdentifier("planner.button.back")

         Button("Follow Route") {
            routePlannerViewModel.confirm()
            onConfirm()
         }
         .buttonStyle(.borderedProminent)
         .tint(.orange)
         .disabled(!routePlannerViewModel.canConfirm)
         .accessibilityIdentifier("planner.button.follow")
      }
      .font(.headline)
      .controlSize(.large)
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
