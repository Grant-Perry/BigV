//
//  RoutePlannerViewModel+Presentation.swift
//  BigV
//

import Foundation

/// Every string the planner's rows show, so no view formats anything.
extension RoutePlannerViewModel {

   func distanceText(for route: PlannedRoute) -> String {
      PlannedRouteFormatters.distance(route.distance)
   }

   func travelTimeText(for route: PlannedRoute) -> String {
      PlannedRouteFormatters.travelTime(route.expectedTravelTime)
   }

   /// Apple ranks its own routes, so the first is the one it recommends. The
   /// provider's own label goes underneath when it has one.
   func title(forCandidateAt index: Int) -> String {
      index == 0 ? "Recommended" : "Alternate \(index)"
   }

   func detail(for route: PlannedRoute) -> String? {
      route.name.isEmpty ? nil : "via \(route.name)"
   }

   func isSelected(_ route: PlannedRoute) -> Bool {
      route.id == selectedCandidate?.id
   }

   /// "+853 FT · 2 climbs", once elevation has landed. `nil` says nothing is
   /// known yet — the row shows the loading whisper off `isEnrichingElevation`.
   func climbSummaryText(for route: PlannedRoute) -> String? {
      guard route.hasElevationProfile, let ascent = route.totalAscent else { return nil }
      return PlannedRouteFormatters.climbSummary(ascent: ascent, climbCount: route.climbs.count)
   }

   func favoriteSummaryText(for favorite: SavedRouteFavorite) -> String {
      PlannedRouteFormatters.distance(favorite.plannedRoute.distance)
   }

   func favoriteSourceLabel(for favorite: SavedRouteFavorite) -> String {
      switch favorite.plannedRoute.source {
         case .appleMaps: "Apple Maps"
         case .gpx: "GPX"
         case .retrace: "Retrace"
         case .trailforks: "Trailforks"
      }
   }
}
