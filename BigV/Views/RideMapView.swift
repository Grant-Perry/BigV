//
//  RideMapView.swift
//  BigV
//

import MapKit
import SwiftUI

/// The live full-screen map page.
struct RideMapView: View {

   let rideViewModel: RideViewModel
   let rideMapViewModel: RideMapViewModel
   let routeGuidanceViewModel: RouteGuidanceViewModel
   let onPlanRoute: () -> Void

   var body: some View {
      ZStack(alignment: .top) {
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
      .overlay(alignment: rideViewModel.radarSide.overlayAlignment) {
         // Traffic awareness must not vanish because the rider swiped to the
         // map; its edge is largely free, so the rail rides there too.
         if rideViewModel.showsRadarTape {
            RideRadarTapeView(
               tracks: rideViewModel.radarTracks,
               isDimmed: rideViewModel.isRadarDimmed
            )
            .frame(maxHeight: 320)
            .padding(rideViewModel.radarSide.paddingEdge, 10)
            .allowsHitTesting(false)
         }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.black)
   }
}

#Preview {
   RideMapView(
      rideViewModel: RideViewModel(),
      rideMapViewModel: RideMapViewModel(),
      routeGuidanceViewModel: RouteGuidanceViewModel()
   ) {}
      .preferredColorScheme(.dark)
}
