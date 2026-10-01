//
//  RouteRecentsSectionView.swift
//  BigV
//

import SwiftUI

/// The last few places the rider navigated to. Tapping one plans a fresh
/// route there from wherever they are now.
struct RouteRecentsSectionView: View {

   let routePlannerViewModel: RoutePlannerViewModel

   /// Fired before a recent opens, so the search field can give up focus.
   let onOpen: () -> Void

   @AppStorage(RouteRecentSectionPreferences.expandedKey)
   private var isExpanded = RouteRecentSectionPreferences.expandedDefault

   var body: some View {
      VStack(alignment: .leading, spacing: 8) {
         RouteSectionHeaderButton(
            title: "Recents",
            count: routePlannerViewModel.recents.count,
            isExpanded: $isExpanded,
            trailingActionTitle: "Clear",
            trailingAction: { routePlannerViewModel.clearRecents() },
            identifier: "planner.section.recents"
         )

         if isExpanded {
            list
         }
      }
   }

   // MARK: - List

   private var list: some View {
      List(routePlannerViewModel.recents) { recent in
         Button {
            onOpen()
            routePlannerViewModel.openRecent(recent)
         } label: {
            RouteRecentRowView(name: recent.name, detail: recent.detail)
         }
         .buttonStyle(.plain)
         .listRowBackground(Color.clear)
         .listRowInsets(.init(top: 4, leading: 0, bottom: 4, trailing: 0))
         .listRowSeparatorTint(RideDashboardTheme.ink(0.12))
         .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
               routePlannerViewModel.removeRecent(id: recent.id)
            } label: {
               Label("Delete", systemImage: "trash")
            }
         }
         .accessibilityIdentifier("planner.recent.\(recent.id.uuidString)")
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .frame(maxHeight: 200)
   }
}

// MARK: - Row

private struct RouteRecentRowView: View {

   let name: String
   let detail: String?

   var body: some View {
      HStack(spacing: 12) {
         Image(systemName: "clock.arrow.circlepath")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(RideDashboardTheme.ink(0.45))
            .frame(width: 22)

         VStack(alignment: .leading, spacing: 2) {
            Text(name)
               .font(.body.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ink)
               .lineLimit(1)

            if let detail, !detail.isEmpty, detail != name {
               Text(detail)
                  .font(.caption)
                  .foregroundStyle(RideDashboardTheme.ink(0.5))
                  .lineLimit(1)
            }
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 6)
      .contentShape(.rect)
   }
}
