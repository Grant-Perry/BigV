//
//  RideRouteMapLayers.swift
//  BigV
//

import MapKit
import SwiftUI

/// Everything a saved ride draws on a map: the route line, radar pass dots and
/// the start/finish endpoints.
///
/// Shared by the inline detail map and the full-screen map so the two can
/// never disagree about what a ride looks like.
struct RideRouteMapLayers: MapContent {

   let route: RideRoute
   var radarPasses: [RideRadarPassAnnotation] = []

   var body: some MapContent {
      MapPolyline(coordinates: route.coordinates)
         .stroke(Color.gpBreadcrumb, style: .routeLine)

      ForEach(radarPasses) { pass in
         radarPassDot(for: pass)
      }

      if let start = route.startCoordinate {
         endpoint(at: start, label: "Ride start", tint: .green)
      }

      if let end = route.endCoordinate {
         endpoint(at: end, label: "Ride finish", tint: .red)
      }
   }

   // MARK: - Passes

   /// A vehicle pass, wearing the same tier palette as the live tape: amber
   /// for an ordinary pass, red for one that peaked high.
   private func radarPassDot(for pass: RideRadarPassAnnotation) -> some MapContent {
      Annotation("Vehicle pass", coordinate: pass.coordinate, anchor: .center) {
         Circle()
            .fill(pass.tier == .high ? RideDashboardTheme.halt : RideDashboardTheme.amber)
            .stroke(.black.opacity(0.6), lineWidth: 1)
            .frame(width: 7, height: 7)
      }
      .annotationTitles(.hidden)
   }

   // MARK: - Endpoints

   private func endpoint(
      at coordinate: CLLocationCoordinate2D,
      label: String,
      tint: Color
   ) -> some MapContent {
      Annotation(label, coordinate: coordinate, anchor: .center) {
         Circle()
            .fill(tint)
            .stroke(.black, lineWidth: 2)
            .frame(width: 12, height: 12)
      }
      .annotationTitles(.hidden)
   }
}
