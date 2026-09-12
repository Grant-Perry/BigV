//
//  RideHistoryView.swift
//  BigV
//

import MapKit
import SwiftData
import SwiftUI

/// The Rides tab: one map stage that stays put, and every ride in one list
/// beneath it.
///
/// A tap on a row puts that ride on the stage — its route, its date, its
/// numbers. Tapping the stage, the row's chevron, or the selected row again
/// opens the full report. No ride is "latest" or "earlier" here; the newest
/// simply starts on the stage.
struct RideHistoryView: View {

   let rideHistoryViewModel: RideHistoryViewModel
   let rideRouteViewModel: RideRouteViewModel
   let rideDetailViewModel: RideDetailViewModel

   @State private var path = NavigationPath()
   @State private var pendingDeletion: [RideHistoryViewModel.Row] = []

   var body: some View {
      NavigationStack(path: $path) {
         Group {
            if rideHistoryViewModel.isEmpty {
               RideHistoryEmptyState()
            } else {
               logbook
            }
         }
         .frame(maxWidth: .infinity, maxHeight: .infinity)
         // A background rather than a ZStack sibling: a full-bleed layer inside
         // a stack inflates the stack past the safe area and the list loses its
         // navigation-bar and footer insets.
         .background {
            RideAtmosphereBackground(scene: .rides)
               .ignoresSafeArea()
         }
         .rideAppFooter()
         .navigationTitle("Rides")
         .navigationBarTitleDisplayMode(.inline)
         .navigationDestination(for: PersistentIdentifier.self) { rideID in
            RideRouteDetailView(rideDetailViewModel: rideDetailViewModel, rideID: rideID)
               .onDisappear { loadStageRoute() }
         }
      }
      .onAppear {
         rideHistoryViewModel.load()
         loadStageRoute()
      }
   }

   // MARK: - Logbook

   private var logbook: some View {
      VStack(spacing: 0) {
         if let selected = rideHistoryViewModel.selectedRow {
            RideHistoryStage(
               row: selected,
               ordinal: rideHistoryViewModel.selectedOrdinal ?? 1,
               rideCount: rideHistoryViewModel.rows.count,
               distanceUnit: rideHistoryViewModel.distanceUnit,
               route: rideRouteViewModel.route,
               isRouteLoaded: rideRouteViewModel.isLoaded,
               onOpen: { open(selected.id) }
            )
            .contextMenu { deleteButton(for: selected) }
         }

         rideList
      }
      .sensoryFeedback(.selection, trigger: rideHistoryViewModel.selectedID)
      .confirmationDialog(
         deletionTitle,
         isPresented: isConfirmingDeletion,
         titleVisibility: .visible
      ) {
         Button(deletionConfirmLabel, role: .destructive) {
            rideHistoryViewModel.delete(ids: Set(pendingDeletion.map(\.id)))
            pendingDeletion = []
            loadStageRoute()
         }

         Button("Keep", role: .cancel) {
            pendingDeletion = []
         }
      } message: {
         Text("This also deletes its recorded route and cannot be undone.")
      }
   }

   // MARK: - List

   /// One quiet container of hairline rows: an index, so it never competes
   /// with the stage for the title of "the ride".
   private var rideList: some View {
      ScrollView {
         LazyVStack(spacing: 0) {
            if let summary = rideHistoryViewModel.summary {
               RideHistoryListHeader(summary: summary)
                  .padding(.horizontal, 12)
                  .padding(.top, 12)
                  .padding(.bottom, 6)
            }

            ForEach(Array(rideHistoryViewModel.rows.enumerated()), id: \.element.id) { index, row in
               let isSelected = rideHistoryViewModel.isSelected(row)

               if index > 0 {
                  Rectangle()
                     .fill(RideDashboardTheme.ink(0.07))
                     .frame(height: 1)
                     .padding(.leading, 52)
               }

               RideHistoryRideCard(
                  row: row,
                  ordinal: index + 1,
                  distanceUnit: rideHistoryViewModel.distanceUnit,
                  isSelected: isSelected,
                  onSelect: {
                     if isSelected {
                        open(row.id)
                     } else {
                        select(row.id)
                     }
                  },
                  onOpen: { open(row.id) }
               )
               .padding(.horizontal, 4)
               .contextMenu { deleteButton(for: row) }
            }
         }
         .padding(.bottom, 6)
         .rideGlassCard(density: .hud, cornerRadius: 20)
         .padding(.horizontal, 16)
         .padding(.top, 12)
         .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
   }

   // MARK: - Selection

   /// Selection and route move in one transaction so the stage's headline
   /// and map change together rather than a frame apart.
   private func select(_ id: PersistentIdentifier) {
      withAnimation(.smooth(duration: 0.28)) {
         rideHistoryViewModel.select(id)
         loadStageRoute()
      }
   }

   private func open(_ id: PersistentIdentifier) {
      path.append(id)
   }

   // MARK: - Stage Route

   private func loadStageRoute() {
      rideRouteViewModel.load(rideHistoryViewModel.selectedRow?.id)
   }

   // MARK: - Deletion

   private func deleteButton(for row: RideHistoryViewModel.Row) -> some View {
      Button("Delete Ride", role: .destructive) {
         pendingDeletion = [row]
      }
   }

   private var isConfirmingDeletion: Binding<Bool> {
      Binding(
         get: { !pendingDeletion.isEmpty },
         set: { isPresented in
            if !isPresented { pendingDeletion = [] }
         }
      )
   }

   private var deletionTitle: String {
      guard let row = pendingDeletion.first, pendingDeletion.count == 1 else {
         return "Delete \(pendingDeletion.count) rides?"
      }
      return "Delete \(row.dateText)?"
   }

   private var deletionConfirmLabel: String {
      pendingDeletion.count == 1 ? "Delete Ride" : "Delete \(pendingDeletion.count) Rides"
   }
}
