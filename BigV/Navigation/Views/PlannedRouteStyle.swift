//
//  PlannedRouteStyle.swift
//  BigV
//

import SwiftUI

/// How a planned route is drawn, wherever it is drawn.
///
/// The breadcrumb is `.gpBreadcrumb`. The guided line is solid `.gpGuidedRoute`
/// so it reads as the line being followed, not a preview.
enum PlannedRouteStyle {

   // MARK: - Colours

   /// The committed / guided route, and the candidate the rider has selected.
   static let line = Color.gpGuidedRoute

   /// Candidates the rider has not selected. Deliberately colourless so the
   /// selected route is the only guided line on the map.
   static let alternateLine = Color.white.opacity(0.32)

   static let destinationMarker = RideDashboardTheme.ember

   // MARK: - Strokes

   /// Wider than the breadcrumb. Solid — this is the line being ridden, not a dash.
   static let stroke = StrokeStyle(
      lineWidth: 6,
      lineCap: .round,
      lineJoin: .round
   )

   static let alternateStroke = StrokeStyle(
      lineWidth: 4,
      lineCap: .round,
      lineJoin: .round,
      dash: [10, 8]
   )
}
