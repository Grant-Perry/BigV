//
//  RideRouteDetailView.swift
//  BigV
//

import SwiftData
import SwiftUI

/// One saved ride: its route on a map, framed to its own bounds, plus its totals.
struct RideRouteDetailView: View {

   let rideRouteViewModel: RideRouteViewModel
   let rideID: PersistentIdentifier

   var body: some View {
      ZStack {
         RideAtmosphereBackground(scene: .summary)
            .ignoresSafeArea()

         ScrollView {
            VStack(spacing: 14) {
               RideRouteMapView(
                  route: rideRouteViewModel.route,
                  isLoaded: rideRouteViewModel.isLoaded,
                  height: 280,
                  radarPasses: rideRouteViewModel.radarPasses
               )

               if let totals = rideRouteViewModel.totals {
                  RideTotalsGridView(totals: totals, identifierPrefix: "detail.tile")
               }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
         }
         .scrollIndicators(.hidden)
      }
      .navigationTitle(rideRouteViewModel.titleText)
      .navigationBarTitleDisplayMode(.inline)
      .task(id: rideID) { rideRouteViewModel.load(rideID) }
      .onDisappear { rideRouteViewModel.clear() }
   }
}
