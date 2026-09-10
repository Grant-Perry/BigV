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
}
