//
//  RouteFavoritesSectionView.swift
//  BigV
//

import SwiftUI

/// The planner's saved routes: a collapsible header and the rows beneath it.
struct RouteFavoritesSectionView: View {

   let routePlannerViewModel: RoutePlannerViewModel

   /// Fired before a favorite opens, so the search field can give up focus.
   let onOpen: () -> Void

   @AppStorage(RouteFavoriteSectionPreferences.expandedKey)
   private var isExpanded = RouteFavoriteSectionPreferences.expandedDefault

   var body: some View {
      VStack(alignment: .leading, spacing: 8) {
         RouteSectionHeaderButton(
            title: "Favorites",
            count: routePlannerViewModel.favorites.count,
            isExpanded: $isExpanded,
            identifier: "planner.section.favorites"
         )

         if isExpanded {
            list
         }
      }
   }

   // MARK: - List

   private var list: some View {
      List(routePlannerViewModel.favorites) { favorite in
         HStack(spacing: 10) {
            Button {
               onOpen()
               routePlannerViewModel.openFavorite(favorite)
            } label: {
               RouteFavoriteRowView(
                  title: favorite.label,
                  sourceLabel: routePlannerViewModel.favoriteSourceLabel(for: favorite),
                  distanceText: routePlannerViewModel.favoriteSummaryText(for: favorite),
                  climbSummary: climbSummary(for: favorite)
               )
            }
            .buttonStyle(.plain)

            FavoriteStarButton(isFavorite: true) {
               routePlannerViewModel.removeFavorite(id: favorite.id)
            }
         }
         .listRowBackground(Color.clear)
         .listRowInsets(.init(top: 4, leading: 0, bottom: 4, trailing: 0))
         .listRowSeparatorTint(RideDashboardTheme.ink(0.12))
         .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
               routePlannerViewModel.removeFavorite(id: favorite.id)
            } label: {
               Label("Delete", systemImage: "trash")
            }
         }
         .accessibilityIdentifier("planner.favorite.\(favorite.id.uuidString)")
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .frame(maxHeight: 220)
   }

   private func climbSummary(for favorite: SavedRouteFavorite) -> String? {
      let route = favorite.plannedRoute
      guard route.hasElevationProfile, let ascent = route.totalAscent else { return nil }
      return PlannedRouteFormatters.climbSummary(ascent: ascent, climbCount: route.climbs.count)
   }
}

// MARK: - Row

private struct RouteFavoriteRowView: View {

   let title: String
   let sourceLabel: String
   let distanceText: String
   let climbSummary: String?

   var body: some View {
      VStack(alignment: .leading, spacing: 4) {
         HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
               .font(.body.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ink)
               .lineLimit(1)

            Spacer(minLength: 8)

            Text(distanceText)
               .font(.caption.weight(.semibold))
               .monospacedDigit()
               .foregroundStyle(RideDashboardTheme.ink(0.55))
         }

         HStack(spacing: 6) {
            Text(sourceLabel)
               .font(.caption2.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ember.opacity(0.85))

            if let climbSummary {
               Text("·")
                  .font(.caption2)
                  .foregroundStyle(RideDashboardTheme.ink(0.25))

               Text(climbSummary)
                  .font(.caption2.weight(.medium))
                  .monospacedDigit()
                  .foregroundStyle(RideDashboardTheme.ink(0.45))
            }
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 6)
      .contentShape(.rect)
   }
}

private struct FavoriteStarButton: View {

   let isFavorite: Bool
   let action: () -> Void

   @State private var boomTrigger = 0

   var body: some View {
      Button {
         boomTrigger += 1
         action()
      } label: {
         StarBoomFavoriteStar(isFavorite: isFavorite, boomTrigger: boomTrigger, font: .body.weight(.semibold))
      }
      .buttonStyle(.plain)
      .accessibilityLabel(isFavorite ? "Remove favorite" : "Save favorite")
   }
}
