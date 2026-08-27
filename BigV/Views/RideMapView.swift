//
//  RideMapView.swift
//  BigV
//

import MapKit
import SwiftUI

/// The live full-screen map page.
struct RideMapView: View {

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
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.black)
   }
}

#Preview {
   RideMapView(
      rideMapViewModel: RideMapViewModel(),
      routeGuidanceViewModel: RouteGuidanceViewModel()
   ) {}
      .preferredColorScheme(.dark)
}
