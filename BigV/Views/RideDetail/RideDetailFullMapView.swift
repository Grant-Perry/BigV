//
//  RideDetailFullMapView.swift
//  BigV
//

import MapKit
import SwiftUI

/// The saved route at full screen: every gesture unlocked, every pass visible.
///
/// Presented from the ride detail map. Chrome floats on Liquid Glass; the map
/// itself is the content, so nothing else competes with it.
struct RideDetailFullMapView: View {

   let route: RideRoute
   let radarPasses: [RideRadarPassAnnotation]
   let titleText: String

   @Environment(\.dismiss) private var dismiss

   var body: some View {
      ZStack(alignment: .top) {
         map
         chrome
      }
      .overlay(alignment: .bottomTrailing) {
         RideRouteMapLegend(showsVehicles: !radarPasses.isEmpty)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .allowsHitTesting(false)
      }
      .preferredColorScheme(.dark)
   }

   // MARK: - Map

   private var map: some View {
      Map(
         initialPosition: route.region.map { .region($0) } ?? .automatic,
         interactionModes: .all
      ) {
         RideRouteMapLayers(route: route, radarPasses: radarPasses)
      }
      .mapStyle(.rideRoute)
      .ignoresSafeArea()
      .accessibilityLabel("Full screen route map")
   }

   // MARK: - Chrome

   private var chrome: some View {
      HStack(spacing: 12) {
         Text(titleText)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(RideDashboardTheme.ink)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .rideGlassChrome(in: .capsule)

         Spacer()

         Button {
            dismiss()
         } label: {
            Image(systemName: "xmark")
               .font(.subheadline.weight(.bold))
               .foregroundStyle(RideDashboardTheme.ink)
               .frame(width: 38, height: 38)
         }
         .rideGlassChrome(in: .circle)
         .accessibilityLabel("Close map")
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
   }
}

#Preview {
   RideDetailFullMapView(route: .empty, radarPasses: [], titleText: "Aug 29 at 9:08 AM")
}
