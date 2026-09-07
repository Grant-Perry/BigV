//
//  RideRouteMapLayers.swift
//  BigV
//

import MapKit
import SwiftUI

/// Everything a saved ride draws on a map: the route line, radar pass marks
/// and the start/finish endpoints.
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
         endpoint(at: start, kind: .start, label: "Ride start")
      }

      if let end = route.endCoordinate {
         endpoint(at: end, kind: .finish, label: "Ride finish")
      }
   }

   // MARK: - Passes

   /// Same language as the live tape: amber circle for an ordinary pass,
   /// red diamond for one that peaked high.
   private func radarPassDot(for pass: RideRadarPassAnnotation) -> some MapContent {
      let isFast = pass.tier == .high
      return Annotation(
         isFast ? "Fast approach" : "Vehicle pass",
         coordinate: pass.coordinate,
         anchor: .center
      ) {
         RideRouteMapMark(kind: isFast ? .fastPass : .vehiclePass)
      }
      .annotationTitles(.hidden)
   }

   // MARK: - Endpoints

   private func endpoint(
      at coordinate: CLLocationCoordinate2D,
      kind: RideRouteMapMark.Kind,
      label: String
   ) -> some MapContent {
      Annotation(label, coordinate: coordinate, anchor: .center) {
         RideRouteMapMark(kind: kind)
      }
      .annotationTitles(.hidden)
   }
}
