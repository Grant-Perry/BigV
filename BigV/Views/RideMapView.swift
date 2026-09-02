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

   var body: some View {
      ZStack(alignment: .top) {
         RideMapCanvasView(
            rideMapViewModel: rideMapViewModel,
            showsCompass: !routeGuidanceViewModel.isActive
         )

         RideMapOverlayView(
            rideMapViewModel: rideMapViewModel,
            routeGuidanceViewModel: routeGuidanceViewModel
         )
      }
      // Traffic awareness must not vanish because the rider swiped to the map.
      .rideRadarTape(
         placement: rideViewModel.radarPlacement,
         tracks: rideViewModel.radarTracks,
         isVisible: rideViewModel.showsRadarTape,
         isDimmed: rideViewModel.isRadarDimmed,
         unitSystem: rideViewModel.unitSystem,
         thickness: mapTapeThickness,
         length: mapTapeLength,
         inset: 10,
         edgeInset: mapTapeEdgeInset
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(RideDashboardTheme.void)
   }

   // MARK: - Radar
   //
   // The map carries furniture on every edge — readouts and the destination
   // chip up top, the FAB stack and Apple's legal line at the bottom — so the
   // tape is capped and held off its edge rather than run corner to corner.

   private var mapTapeThickness: CGFloat {
      rideViewModel.radarPlacement.isVertical
         ? RideRadarTapeView.compactWidth
         : RideRadarTapeView.barThickness
   }

   private var mapTapeLength: CGFloat? {
      rideViewModel.radarPlacement.isVertical ? 300 : nil
   }

   private var mapTapeEdgeInset: CGFloat {
      switch rideViewModel.radarPlacement {
         case .leading, .trailing: 8
         // Below the speed and distance readouts.
         case .top: 108
         // Above the whole FAB stack and Apple's legal line, both of which the
         // rider taps or App Review requires visible.
         case .bottom: 150
      }
   }
}

#Preview {
   RideMapView(
      rideViewModel: RideViewModel(),
      rideMapViewModel: RideMapViewModel(),
      routeGuidanceViewModel: RouteGuidanceViewModel()
   )
   .preferredColorScheme(.dark)
}
