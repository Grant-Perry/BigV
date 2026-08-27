//
//  PlannedRouteStyle.swift
//  BigV
//

import SwiftUI

/// How a planned route is drawn, wherever it is drawn.
///
/// The breadcrumb is a solid cyan line and stays that way. Where the rider is
/// going has to be unmistakable against where they have been at a glance, in
/// sunlight, at speed — so it differs in both hue and stroke: warm amber instead
/// of cool cyan, dashed instead of solid. Dashes read as intent rather than
/// record, which is the same convention Apple Maps uses for a leg not yet
/// travelled.
enum PlannedRouteStyle {

   // MARK: - Colours

   /// The committed route, and the candidate the rider currently has selected.
   static let line = Color.orange

   /// Candidates the rider has not selected. Deliberately colourless so the
   /// selected route is the only warm line on the map.
   static let alternateLine = Color.white.opacity(0.32)

   static let destinationMarker = Color.orange

   // MARK: - Strokes

   /// Wider than the breadcrumb as well as dashed: a planned line is read ahead
   /// of the rider, further from the centre of their attention.
   static let stroke = StrokeStyle(
      lineWidth: 6,
      lineCap: .round,
      lineJoin: .round,
      dash: [16, 10]
   )

   static let alternateStroke = StrokeStyle(
      lineWidth: 4,
      lineCap: .round,
      lineJoin: .round,
      dash: [10, 8]
   )
}
