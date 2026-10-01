//
//  RouteSearchStageView.swift
//  BigV
//

import SwiftUI
import UniformTypeIdentifiers

/// The search field and its live results, with the fast ways in above them:
/// Home, Recents, Favorites.
///
/// Does not steal focus on appear: the tab bar has to stay reachable. The
/// keyboard only comes up when the rider taps the field, and tapping empty
/// chrome puts it away again so the tabs are never trapped behind it.
struct RouteSearchStageView: View {

   @Bindable var routePlannerViewModel: RoutePlannerViewModel
   let rideViewModel: RideViewModel
   let routeHomeAddressViewModel: RouteHomeAddressViewModel
   let onStopRoute: () -> Void

   @FocusState private var isFieldFocused: Bool
   @State private var isShowingGPXImporter = false
   @State private var isShowingHomeSheet = false

   /// GPX has no system UTType; files usually arrive typed by extension, with
   /// plain XML as the fallback some apps export.
   private static let gpxTypes: [UTType] = [
      UTType(filenameExtension: "gpx") ?? .xml,
      .xml
   ]

   /// Shortcuts step aside once the rider is typing: the results need the room.
   private var isSearching: Bool { !routePlannerViewModel.query.isEmpty }

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
         .sheet(isPresented: $isShowingHomeSheet) {
            RouteHomeAddressSheet(routeHomeAddressViewModel: routeHomeAddressViewModel)
         }
   }

   @ViewBuilder
   private var resultsColumn: some View {
      VStack(spacing: 12) {
         if routePlannerViewModel.hasActiveRoute,
            let destinationName = routePlannerViewModel.activeDestinationName {
            ActiveRouteBannerView(
               destinationName: destinationName,
               isRideActive: rideViewModel.isRideActive,
               onStopRoute: onStopRoute
            )
         }

         if !isSearching {
            shortcuts
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

   // MARK: - Shortcuts

   @ViewBuilder
   private var shortcuts: some View {
      RouteHomeButton(
         homeLabel: routePlannerViewModel.homeLabel,
         onRideHome: {
            isFieldFocused = false
            routePlannerViewModel.rideHome()
         },
         onSetHome: {
            isFieldFocused = false
            isShowingHomeSheet = true
         }
      )

      if routePlannerViewModel.hasRecents {
         RouteRecentsSectionView(
            routePlannerViewModel: routePlannerViewModel,
            onOpen: { isFieldFocused = false }
         )
      }

      if routePlannerViewModel.hasFavorites {
         RouteFavoritesSectionView(
            routePlannerViewModel: routePlannerViewModel,
            onOpen: { isFieldFocused = false }
         )
      }
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
            .foregroundStyle(RideDashboardTheme.ink(0.75))
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
            .foregroundStyle(RideDashboardTheme.ink(0.45))

         TextField("Address or place", text: $routePlannerViewModel.query)
            .font(.title3.weight(.medium))
            .foregroundStyle(RideDashboardTheme.ink)
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
                  .foregroundStyle(RideDashboardTheme.ink(0.4))
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
         .listRowSeparatorTint(RideDashboardTheme.ink(0.12))
         .accessibilityIdentifier("planner.suggestion.\(index)")
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .scrollDismissesKeyboard(.immediately)
   }

   private var hint: some View {
      Text("Apple provides the cycling route. Coverage is best in cities.")
         .font(.footnote)
         .foregroundStyle(RideDashboardTheme.ink(0.35))
         .multilineTextAlignment(.center)
         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
         .padding(.top, 24)
         .contentShape(.rect)
         .onTapGesture { isFieldFocused = false }
   }

   private func statusMessage(_ message: String) -> some View {
      Text(message)
         .font(.subheadline.weight(.medium))
         .foregroundStyle(RideDashboardTheme.ink(0.5))
         .multilineTextAlignment(.center)
         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
         .padding(.top, 24)
         .contentShape(.rect)
         .onTapGesture { isFieldFocused = false }
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
      RouteSearchStageView(
         routePlannerViewModel: RoutePlannerViewModel(),
         rideViewModel: RideViewModel(),
         routeHomeAddressViewModel: RouteHomeAddressViewModel(),
         onStopRoute: {}
      )
   }
   .preferredColorScheme(.dark)
}
