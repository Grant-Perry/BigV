//
//  RideMapCanvasView.swift
//  BigV
//

import MapKit
import SwiftUI

/// Owns the camera binding, the breadcrumb and the planned route, and nothing
/// else. Shared by the full map page and the dashboard drawer.
struct RideMapCanvasView: View {

   @Bindable var rideMapViewModel: RideMapViewModel
   var showsCompass: Bool = true

   /// `nil` takes the view model's own follow-aware modes, which is what the
   /// full map page wants. The drawer names its own set instead.
   var interactionModes: MapInteractionModes?

   /// Bounds are an initialiser parameter rather than a modifier, and they are
   /// the only zoom lever a `userLocation` camera gives.
   var cameraBounds: MapCameraBounds?

   var body: some View {
      GeometryReader { proxy in
         if proxy.size.width >= 8, proxy.size.height >= 8 {
            mapCanvas
               .frame(width: proxy.size.width, height: proxy.size.height)
         }
      }
   }

   // MARK: - Canvas

   /// TabView keeps the off-screen map page in the hierarchy at 0×0. MapKit
   /// then asks Metal for a zero drawable — that is the Start crash, not the
   /// WatchConnectivity noise in the same console dump.
   private var mapCanvas: some View {
      Map(
         position: $rideMapViewModel.cameraPosition,
         bounds: cameraBounds,
         interactionModes: interactionModes ?? rideMapViewModel.interactionModes
      ) {
         if rideMapViewModel.hasPlannedRoute {
            MapPolyline(coordinates: rideMapViewModel.plannedRouteCoordinates)
               .stroke(PlannedRouteStyle.line, style: PlannedRouteStyle.stroke)
         }

         if let focused = rideMapViewModel.focusedManeuverCoordinate {
            Annotation("Selected turn", coordinate: focused, anchor: .center) {
               Circle()
                  .fill(RideDashboardTheme.ember)
                  .stroke(.white, lineWidth: 2)
                  .frame(width: 12, height: 12)
            }
            .annotationTitles(.hidden)
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
               .stroke(Color.gpBreadcrumb, style: .routeLine)
         }

         UserAnnotation()
      }
      .mapStyle(rideMapViewModel.mapStyle)
      .mapControls {
         if showsCompass {
            MapCompass()
         }
      }
      .onMapCameraChange(frequency: .continuous) { context in
         rideMapViewModel.rememberCamera(context.camera)
      }
      .onChange(of: rideMapViewModel.plannedRouteID) { _, newID in
         guard newID != nil else { return }
         rideMapViewModel.framePlannedRoute()
      }
      .onChange(of: rideMapViewModel.isIdle) { _, isIdle in
         guard !isIdle else { return }
         rideMapViewModel.recenter()
      }
   }
}
