//
//  RideRouteMapHighlight.swift
//  BigV
//

import SwiftUI

/// One lit slice on a saved-ride map: the thinned track and the tint that
/// names it as a lap or a climb.
struct RideRouteMapHighlight {

   let route: RideRoute
   let tint: Color

   init(segment: RideSplitSegment) {
      route = segment.route
      switch segment.id {
      case .lap:
         tint = RideDashboardTheme.ice
      case .climb:
         tint = RideDashboardTheme.ember
      }
   }

   /// The slice for a pinned split, or `nil` when nothing is pinned or the
   /// split has too few points to draw.
   ///
   /// Every map resolves its own highlight from the pinned split with this,
   /// so the slice it lights and the camera it frames always come from the
   /// same body pass — a parent handing down a stale highlight can never
   /// leave the camera parked on the previous lap.
   static func highlight(
      for id: RideSplitID?,
      in segments: [RideSplitSegment]
   ) -> RideRouteMapHighlight? {
      guard let id, let segment = segments.first(where: { $0.id == id }) else {
         return nil
      }
      let built = RideRouteMapHighlight(segment: segment)
      return built.route.isDrawable ? built : nil
   }
}
