//
//  RouteSearchStageView.swift
//  BigV
//

import SwiftUI
import UniformTypeIdentifiers

/// The search field and its live results.
///
/// Does not steal focus on appear: the tab bar has to stay reachable. The
/// keyboard only comes up when the rider taps the field, and tapping empty
/// chrome puts it away again so the tabs are never trapped behind it.
struct RouteSearchStageView: View {

   @Bindable var routePlannerViewModel: RoutePlannerViewModel

   @FocusState private var isFieldFocused: Bool
   @State private var isShowingGPXImporter = false
   @AppStorage(RouteFavoriteSectionPreferences.expandedKey)
   private var isFavoritesExpanded = RouteFavoriteSectionPreferences.expandedDefault
   @State private var favoritesSectionBoomTrigger = 0

   /// GPX has no system UTType; files usually arrive typed by extension, with
   /// plain XML as the fallback some apps export.
   private static let gpxTypes: [UTType] = [
      UTType(filenameExtension: "gpx") ?? .xml,
      .xml
   ]

   var body: some View {
      resultsColumn
         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
         .safeAreaBar(edge: .top, spacing: 12) {
            searchField
               .padding(.horizontal, 16)
               .padding(.top, 8)
         }
         .fileImporter(
            isPresented: $isShowingGPXImporter,
            allowedContentTypes: Self.gpxTypes,
            allowsMultipleSelection: false
         ) { result in
            if case .success(let urls) = result, let url = urls.first {
               routePlannerViewModel.importGPXRoute(from: url)
            }
         }
   }

   @ViewBuilder
   private var resultsColumn: some View {
      VStack(spacing: 12) {
         if routePlannerViewModel.hasFavorites {
            favoritesSection
         }

         if let planningFailure = routePlannerViewModel.planningFailure {
            RoutePlanningFailureView(failure: planningFailure)
         }

         if let gpxFailure = routePlannerViewModel.gpxImportFailureMessage {
            statusMessage(gpxFailure)
               .frame(maxHeight: 60)
         }

         results

         gpxImportButton
      }
      .padding(.horizontal, 16)
   }

   // MARK: - Favorites

   private var favoritesSection: some View {
      VStack(alignment: .leading, spacing: 8) {
         Button {
            favoritesSectionBoomTrigger += 1
            withAnimation(.easeInOut(duration: 0.2)) {
               isFavoritesExpanded.toggle()
            }
         } label: {
            HStack(spacing: 8) {
               Text("Favorites")
                  .font(.subheadline.weight(.bold))
                  .foregroundStyle(.white.opacity(0.85))

               Text("\(routePlannerViewModel.favorites.count)")
                  .font(.caption.weight(.semibold))
                  .monospacedDigit()
                  .foregroundStyle(.white.opacity(0.45))

               Spacer(minLength: 0)

               StarBoomChevron(
                  isExpanded: isFavoritesExpanded,
                  boomTrigger: favoritesSectionBoomTrigger,
                  foregroundColor: .white.opacity(0.55)
               )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .rideGlassCard(density: .hud)
         }
         .buttonStyle(.plain)
         .accessibilityIdentifier("planner.section.favorites")

         if isFavoritesExpanded {
            favoritesList
         }
      }
   }

   private var favoritesList: some View {
      List(routePlannerViewModel.favorites) { favorite in
         HStack(spacing: 10) {
            Button {
               isFieldFocused = false
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
         .listRowSeparatorTint(.white.opacity(0.12))
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

   // MARK: - GPX Import

   /// One-shot import: the file becomes the previewed route, not a library
   /// entry. Sits under the results so search stays the primary way in.
   private var gpxImportButton: some View {
      Button {
         isFieldFocused = false
         isShowingGPXImporter = true
      } label: {
         Label("Import GPX Route", systemImage: "square.and.arrow.down")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.75))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
      }
      .buttonStyle(.plain)
      .rideGlassChrome(in: .capsule)
      .padding(.bottom, 10)
      .accessibilityIdentifier("planner.button.importGPX")
   }

   // MARK: - Field

   private var searchField: some View {
      HStack(spacing: 10) {
         Image(systemName: .searchIcon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.45))

         TextField("Address or place", text: $routePlannerViewModel.query)
            .font(.title3.weight(.medium))
            .foregroundStyle(.white)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused($isFieldFocused)
            .accessibilityIdentifier("planner.field.search")

         if !routePlannerViewModel.query.isEmpty {
            Button {
               routePlannerViewModel.query = ""
            } label: {
               Image(systemName: .clearIcon)
                  .font(.subheadline)
                  .foregroundStyle(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear search")
         }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .rideGlassChrome(in: .rect(cornerRadius: 16, style: .continuous))
   }

   // MARK: - Results

   @ViewBuilder
   private var results: some View {
      if let message = routePlannerViewModel.searchStatusMessage {
         statusMessage(message)
      } else if routePlannerViewModel.suggestions.isEmpty {
         hint
      } else {
         suggestionList
      }
   }

   private var suggestionList: some View {
      List(Array(routePlannerViewModel.suggestions.enumerated()), id: \.element.id) { index, suggestion in
         Button {
            isFieldFocused = false
            routePlannerViewModel.select(suggestion)
         } label: {
            RouteSuggestionRowView(suggestion: suggestion)
         }
         .buttonStyle(.plain)
         .listRowBackground(Color.clear)
         .listRowInsets(.init(top: 4, leading: 0, bottom: 4, trailing: 0))
         .listRowSeparatorTint(.white.opacity(0.12))
         .accessibilityIdentifier("planner.suggestion.\(index)")
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .scrollDismissesKeyboard(.immediately)
   }

   private var hint: some View {
      Text("Apple provides the cycling route. Coverage is best in cities.")
         .font(.footnote)
         .foregroundStyle(.white.opacity(0.35))
         .multilineTextAlignment(.center)
         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
         .padding(.top, 24)
         .contentShape(.rect)
         .onTapGesture { isFieldFocused = false }
   }

   private func statusMessage(_ message: String) -> some View {
      Text(message)
         .font(.subheadline.weight(.medium))
         .foregroundStyle(.white.opacity(0.5))
         .multilineTextAlignment(.center)
         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
         .padding(.top, 24)
         .contentShape(.rect)
         .onTapGesture { isFieldFocused = false }
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
               .foregroundStyle(.white)
               .lineLimit(1)

            Spacer(minLength: 8)

            Text(distanceText)
               .font(.caption.weight(.semibold))
               .monospacedDigit()
               .foregroundStyle(.white.opacity(0.55))
         }

         HStack(spacing: 6) {
            Text(sourceLabel)
               .font(.caption2.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ember.opacity(0.85))

            if let climbSummary {
               Text("·")
                  .font(.caption2)
                  .foregroundStyle(.white.opacity(0.25))

               Text(climbSummary)
                  .font(.caption2.weight(.medium))
                  .monospacedDigit()
                  .foregroundStyle(.white.opacity(0.45))
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

private struct RouteSuggestionRowView: View {

   let suggestion: RouteSearchSuggestion

   var body: some View {
      VStack(alignment: .leading, spacing: 2) {
         Text(suggestion.title)
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)

         if suggestion.hasSubtitle {
            Text(suggestion.subtitle)
               .font(.caption)
               .foregroundStyle(.white.opacity(0.5))
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 6)
      .contentShape(.rect)
   }
}

// MARK: - Icons

private extension String {
   static let searchIcon = "magnifyingglass"
   static let clearIcon = "xmark.circle.fill"
}

#Preview {
   ZStack {
      Color.black.ignoresSafeArea()
      RouteSearchStageView(routePlannerViewModel: RoutePlannerViewModel())
   }
   .preferredColorScheme(.dark)
}
