//
//  RouteSearchStageView.swift
//  BigV
//

import SwiftUI

/// The search field and its live results.
///
/// Does not steal focus on appear: the tab bar has to stay reachable. The
/// keyboard only comes up when the rider taps the field, and tapping empty
/// chrome puts it away again so the tabs are never trapped behind it.
struct RouteSearchStageView: View {

   @Bindable var routePlannerViewModel: RoutePlannerViewModel

   @FocusState private var isFieldFocused: Bool

   var body: some View {
      resultsColumn
         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
         .safeAreaBar(edge: .top, spacing: 12) {
            searchField
               .padding(.horizontal, 16)
               .padding(.top, 8)
         }
   }

   @ViewBuilder
   private var resultsColumn: some View {
      VStack(spacing: 12) {
         if let planningFailure = routePlannerViewModel.planningFailure {
            RoutePlanningFailureView(failure: planningFailure)
         }

         results
      }
      .padding(.horizontal, 16)
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
