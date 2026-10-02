//
//  RouteHomeAddressSheet.swift
//  BigV
//

import SwiftUI

/// Sets, replaces or removes the rider's home address.
///
/// Reached from Settings and from the Ride To tab's Home button when no home
/// is set yet, so a rider on a trail never has to leave the planner to make
/// the button work.
struct RouteHomeAddressSheet: View {

   let routeHomeAddressViewModel: RouteHomeAddressViewModel

   @Environment(\.dismiss) private var dismiss
   @FocusState private var isFieldFocused: Bool

   var body: some View {
      NavigationStack {
         VStack(spacing: 12) {
            if let label = routeHomeAddressViewModel.homeLabel {
               currentHome(label)
            }

            results
         }
         .padding(.horizontal, 16)
         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
         .safeAreaBar(edge: .top, spacing: 12) {
            searchField
               .padding(.horizontal, 16)
               .padding(.top, 8)
         }
         .background {
            RideAtmosphereBackground(scene: .rideTo)
               .ignoresSafeArea()
         }
         .navigationTitle("Home Address")
         .navigationBarTitleDisplayMode(.inline)
         .toolbarBackgroundVisibility(.visible, for: .navigationBar)
         .toolbar {
            ToolbarItem(placement: .confirmationAction) {
               Button("Done") { dismiss() }
                  .accessibilityIdentifier("home.button.done")
            }
         }
      }
      .onAppear {
         routeHomeAddressViewModel.begin()
         isFieldFocused = !routeHomeAddressViewModel.hasHome
      }
      .onDisappear { routeHomeAddressViewModel.end() }
      .rideAppearance()
   }

   // MARK: - Current Home

   private func currentHome(_ label: String) -> some View {
      HStack(spacing: 12) {
         Image(systemName: .homeIcon)
            .font(.title3.weight(.semibold))
            .foregroundStyle(RideDashboardTheme.ember)

         VStack(alignment: .leading, spacing: 2) {
            Text("Home")
               .font(.caption.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ink(0.5))

            Text(label)
               .font(.subheadline.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ink)
               .lineLimit(2)
         }

         Spacer(minLength: 8)

         Button("Remove", role: .destructive) {
            routeHomeAddressViewModel.clearHome()
         }
         .font(.caption.weight(.semibold))
         .buttonStyle(.bordered)
         .tint(.red)
         .accessibilityIdentifier("home.button.remove")
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .rideGlassCard(density: .hud)
   }

   // MARK: - Field

   private var searchField: some View {
      HStack(spacing: 10) {
         Image(systemName: .searchIcon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(RideDashboardTheme.ink(0.45))

         TextField(
            routeHomeAddressViewModel.hasHome ? "Change home address" : "Your home address",
            text: Bindable(routeHomeAddressViewModel).query
         )
         .font(.title3.weight(.medium))
         .foregroundStyle(RideDashboardTheme.ink)
         .textContentType(.fullStreetAddress)
         .textInputAutocapitalization(.words)
         .autocorrectionDisabled()
         .submitLabel(.search)
         .focused($isFieldFocused)
         .accessibilityIdentifier("home.field.search")

         if routeHomeAddressViewModel.isResolving {
            ProgressView()
               .controlSize(.small)
               .tint(RideDashboardTheme.ink(0.6))
         } else if !routeHomeAddressViewModel.query.isEmpty {
            Button {
               routeHomeAddressViewModel.query = ""
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
      if let message = routeHomeAddressViewModel.statusMessage {
         statusMessage(message)
      } else if routeHomeAddressViewModel.suggestions.isEmpty {
         statusMessage("Pick an address and the Home button on Ride To plans the way back from wherever you are.")
      } else {
         suggestionList
      }
   }

   private var suggestionList: some View {
      List(Array(routeHomeAddressViewModel.suggestions.enumerated()), id: \.element.id) { index, suggestion in
         Button {
            isFieldFocused = false
            Task {
               if await routeHomeAddressViewModel.choose(suggestion) {
                  dismiss()
               }
            }
         } label: {
            RouteSuggestionRowView(suggestion: suggestion)
         }
         .buttonStyle(.plain)
         .disabled(routeHomeAddressViewModel.isResolving)
         .listRowBackground(Color.clear)
         .listRowInsets(.init(top: 4, leading: 0, bottom: 4, trailing: 0))
         .listRowSeparatorTint(RideDashboardTheme.ink(0.12))
         .accessibilityIdentifier("home.suggestion.\(index)")
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .scrollDismissesKeyboard(.immediately)
   }

   private func statusMessage(_ message: String) -> some View {
      Text(message)
         .font(.footnote)
         .foregroundStyle(RideDashboardTheme.ink(0.4))
         .multilineTextAlignment(.center)
         .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
         .padding(.top, 24)
         .contentShape(.rect)
         .onTapGesture { isFieldFocused = false }
   }
}

// MARK: - Icons

private extension String {
   static let homeIcon = "house.fill"
   static let searchIcon = "magnifyingglass"
   static let clearIcon = "xmark.circle.fill"
}

#Preview {
   RouteHomeAddressSheet(routeHomeAddressViewModel: RouteHomeAddressViewModel())
      .environment(RideAppearanceSettings())
}
