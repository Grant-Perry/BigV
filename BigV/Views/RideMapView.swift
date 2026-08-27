//
//  RideMapView.swift
//  BigV
//

import MapKit
import SwiftUI

/// The live map page: where the rider is, where they have been, and the two
/// numbers that make the page usable without swiping back to the dashboard.
///
/// Nothing here animates or recomputes per frame. The map runs for hours beside
/// active GPS recording, so the basemap is flat and stripped of points of
/// interest, and the canvas and the overlay are separate views so a settling
/// camera never redraws the readouts and a new speed never redraws the map.
struct RideMapView: View {

   let rideMapViewModel: RideMapViewModel
   let routeGuidanceViewModel: RouteGuidanceViewModel
   let onPlanRoute: () -> Void

   var body: some View {
      ZStack(alignment: .bottom) {
         // The map compass lives in the top-trailing corner, which is exactly
         // where the guidance banner and its controls go. The banner wins: a turn
         // matters more than a bearing, and the user annotation already shows
         // which way the rider faces.
         RideMapCanvasView(
            rideMapViewModel: rideMapViewModel,
            showsCompass: !routeGuidanceViewModel.isActive
         )

         RideMapOverlayView(
            rideMapViewModel: rideMapViewModel,
            routeGuidanceViewModel: routeGuidanceViewModel,
            onPlanRoute: onPlanRoute
         )
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.black)
   }
}

// MARK: - Canvas

/// Owns the camera binding, the breadcrumb and the planned route, and nothing
/// else.
///
/// The planned route is drawn first so the breadcrumb sits on top of it: where
/// the rider has actually been is the record, and must never be obscured by
/// where they intended to go.
private struct RideMapCanvasView: View {

   @Bindable var rideMapViewModel: RideMapViewModel
   let showsCompass: Bool

   var body: some View {
      Map(
         position: $rideMapViewModel.cameraPosition,
         interactionModes: rideMapViewModel.interactionModes
      ) {
         if rideMapViewModel.hasPlannedRoute {
            MapPolyline(coordinates: rideMapViewModel.plannedRouteCoordinates)
               .stroke(PlannedRouteStyle.line, style: PlannedRouteStyle.stroke)
         }

         if let destination = rideMapViewModel.destinationCoordinate,
            let name = rideMapViewModel.destinationName {
            Annotation(name, coordinate: destination, anchor: .center) {
               Circle()
                  .fill(PlannedRouteStyle.destinationMarker)
                  .stroke(.black, lineWidth: 2)
                  .frame(width: 14, height: 14)
            }
            .annotationTitles(.hidden)
         }

         if rideMapViewModel.hasRoute {
            MapPolyline(coordinates: rideMapViewModel.routeCoordinates)
               .stroke(.cyan, style: .routeLine)
         }

         UserAnnotation()
      }
      .mapStyle(.rideRoute)
      .mapControls {
         if showsCompass {
            MapCompass()
         }
      }
      .onMapCameraChange(frequency: .continuous) { context in
         rideMapViewModel.rememberCamera(context.camera)
      }
      // The view model refuses this mid-ride, so a reroute never takes the camera
      // off a rider who is at that moment lost.
      .onChange(of: rideMapViewModel.plannedRouteID) { _, newID in
         guard newID != nil else { return }
         rideMapViewModel.framePlannedRoute()
      }
      // Framing a new route leaves the camera parked. Starting a ride must hand
      // it back without the rider hunting for the re-center control first.
      .onChange(of: rideMapViewModel.isIdle) { _, isIdle in
         guard !isIdle else { return }
         rideMapViewModel.recenter()
      }
   }
}

#Preview {
   RideMapView(
      rideMapViewModel: RideMapViewModel(),
      routeGuidanceViewModel: RouteGuidanceViewModel()
   ) {}
      .preferredColorScheme(.dark)
}
