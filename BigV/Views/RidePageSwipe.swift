//
//  RidePageSwipe.swift
//  BigV
//

import SwiftUI

/// Reads a drag as a page turn, or refuses to.
///
/// Lives outside the pager because the dashboard has to make the same call: its
/// map drawer pans now, so the page-turning drag is recognised on the metrics
/// above the drawer rather than across the whole page.
enum RidePageSwipe {

   /// Points a drag must cover horizontally before it counts as a page turn.
   static let minimumDistance: CGFloat = 40

   static func isForward(_ value: DragGesture.Value) -> Bool {
      isHorizontal(value) && value.translation.width < -60
   }

   static func isBack(_ value: DragGesture.Value) -> Bool {
      isHorizontal(value) && value.translation.width > 60
   }

   static func startsAtLeadingEdge(_ value: DragGesture.Value) -> Bool {
      value.startLocation.x < 36
   }

   private static func isHorizontal(_ value: DragGesture.Value) -> Bool {
      abs(value.translation.width) > abs(value.translation.height) * 1.3
   }
}
