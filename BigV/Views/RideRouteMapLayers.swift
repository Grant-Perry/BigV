//
//  RideRouteMapLayers.swift
//  BigV
//

import MapKit
import SwiftUI

/// Everything a saved ride draws on a map: the route line, radar pass marks
/// and the start/finish endpoints. An optional highlight dims the full ride
/// and lights one lap or climb.
///
/// Shared by the inline detail map and the full-screen map so the two can
/// never disagree about what a ride looks like.
struct RideRouteMapLayers: MapContent {

   let route: RideRoute
   var radarPasses: [RideRadarPassAnnotation] = []
   var highlight: RideRouteMapHighlight?

   var body: some MapContent {
      routeLine

      ForEach(radarPasses) { pass in
         radarPassDot(for: pass)
      }

      if let start = route.startCoordinate {
         endpoint(at: start, kind: .start, tint: .green, label: "Ride start")
      }

      if let end = route.endCoordinate {
         endpoint(at: end, kind: .finish, tint: .green, label: "Ride finish")
      }

      if let highlight, highlight.route.isDrawable {
         splitMarks(for: highlight)
      }
   }

   // MARK: - Line

   @MapContentBuilder
   private var routeLine: some MapContent {
      if let highlight, highlight.route.isDrawable {
         MapPolyline(coordinates: route.coordinates)
            .stroke(Color.gpBreadcrumb.opacity(0.32), style: .dimmedRouteLine)
         MapPolyline(coordinates: highlight.route.coordinates)
            .stroke(highlight.tint, style: .highlightRouteLine)
      } else {
         MapPolyline(coordinates: route.coordinates)
            .stroke(Color.gpBreadcrumb, style: .routeLine)
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
      tint: Color,
      label: String
   ) -> some MapContent {
      Annotation(label, coordinate: coordinate, anchor: .center) {
         RideRouteMapMark(kind: kind, tint: tint)
      }
      .annotationTitles(.hidden)
   }

   // MARK: - Highlighted split

   @MapContentBuilder
   private func splitMarks(for highlight: RideRouteMapHighlight) -> some MapContent {
      if let start = highlight.route.startCoordinate {
         endpoint(at: start, kind: .splitStart, tint: highlight.tint, label: "Split start")
      }

      if let end = highlight.route.endCoordinate {
         endpoint(at: end, kind: .splitEnd, tint: highlight.tint, label: "Split end")
      }
   }
}
