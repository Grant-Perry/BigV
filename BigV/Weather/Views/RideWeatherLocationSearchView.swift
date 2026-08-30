//
//  RideWeatherLocationSearchView.swift
//  BigV
//

import MapKit
import SwiftUI

/// City / postal-code search for the weather sheet.
///
/// A rider checking tomorrow's start town, or a headwind two valleys over,
/// should not have to drive there first. The pick is kept, so the dashboard chip
/// follows it until the rider taps back to the GPS.
struct RideWeatherLocationSearchView: View {

   let onSelect: (CLLocationCoordinate2D, String) -> Void

   @Environment(\.dismiss) private var dismiss
   @State private var searchText = ""
   @State private var results: [MKMapItem] = []
   @State private var isSearching = false

   var body: some View {
      NavigationStack {
         content
            // A background rather than a ZStack sibling: a full-bleed layer
            // inside a stack inflates the stack past the safe area and the
            // list loses its navigation-bar inset.
            .background {
               RideAtmosphereBackground()
                  .ignoresSafeArea()
            }
            .navigationTitle("Change Location")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "City, address, or postal code")
            .toolbar {
               ToolbarItem(placement: .cancellationAction) {
                  Button("Cancel", role: .cancel) { dismiss() }
               }
            }
      }
      .preferredColorScheme(.dark)
      .task(id: searchText) {
         // Debounced by the task's own cancellation: a new keystroke replaces
         // this one before the sleep completes, so only the last query flies.
         try? await Task.sleep(for: .milliseconds(400))
         guard !Task.isCancelled else { return }
         await search(searchText)
      }
   }

   // MARK: - Content

   @ViewBuilder
   private var content: some View {
      if isSearching {
         ProgressView()
            .tint(.white)
      } else if !results.isEmpty {
         resultList
      } else if !trimmedQuery.isEmpty {
         ContentUnavailableView(
            "No Results",
            systemImage: "mappin.slash",
            description: Text("Try a city, address, or postal code.")
         )
      } else {
         ContentUnavailableView(
            "Search",
            systemImage: "magnifyingglass",
            description: Text("Weather stays where you pick until you tap the location arrow.")
         )
      }
   }

   private var resultList: some View {
      ScrollView {
         LazyVStack(spacing: 8) {
            ForEach(Array(results.enumerated()), id: \.offset) { _, item in
               Button {
                  select(item)
               } label: {
                  resultRow(item)
               }
               .buttonStyle(.plain)
            }
         }
         .padding(.horizontal, 16)
         .padding(.vertical, 12)
      }
      .scrollIndicators(.hidden)
   }

   private func resultRow(_ item: MKMapItem) -> some View {
      HStack(spacing: 12) {
         Image(systemName: "mappin.circle.fill")
            .font(.title3)
            .foregroundStyle(RideChromeTokens.ice)

         VStack(alignment: .leading, spacing: 2) {
            Text(item.name ?? "Unknown")
               .font(.subheadline.weight(.semibold))
               .foregroundStyle(.white)

            if let address = address(for: item) {
               Text(address)
                  .font(.caption)
                  .foregroundStyle(.white.opacity(0.55))
                  .lineLimit(2)
            }
         }

         Spacer(minLength: 0)
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .rideGlassCard()
      .contentShape(.rect)
   }

   // MARK: - Search

   private var trimmedQuery: String {
      searchText.trimmingCharacters(in: .whitespacesAndNewlines)
   }

   private func search(_ query: String) async {
      let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else {
         results = []
         isSearching = false
         return
      }

      isSearching = true
      defer { isSearching = false }

      let request = MKLocalSearch.Request()
      request.naturalLanguageQuery = trimmed

      do {
         results = try await MKLocalSearch(request: request).start().mapItems
      } catch {
         DebugPrint(mode: .weather, "Weather location search failed: \(error.localizedDescription)")
         results = []
      }
   }

   // MARK: - Selection

   private func select(_ item: MKMapItem) {
      let coordinate = item.location.coordinate
      guard CLLocationCoordinate2DIsValid(coordinate) else { return }

      onSelect(coordinate, label(for: item))
      dismiss()
   }

   private func label(for item: MKMapItem) -> String {
      if let city = item.addressRepresentations?.cityName, !city.isEmpty { return city }
      return address(for: item) ?? item.name ?? "Selected place"
   }

   private func address(for item: MKMapItem) -> String? {
      item.addressRepresentations?.cityWithContext
   }
}
