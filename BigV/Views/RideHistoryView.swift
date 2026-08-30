//
//  RideHistoryView.swift
//  BigV
//

import SwiftData
import SwiftUI

/// The Rides tab: latest ride as a cinematic card, then the rest.
struct RideHistoryView: View {

   let rideHistoryViewModel: RideHistoryViewModel
   let rideRouteViewModel: RideRouteViewModel
   let rideDetailViewModel: RideDetailViewModel

   @State private var pendingDeletion: [RideHistoryViewModel.Row] = []

   var body: some View {
      NavigationStack {
         Group {
            if rideHistoryViewModel.isEmpty {
               RideHistoryEmptyState()
            } else {
               rideList
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
         .navigationBarTitleDisplayMode(.large)
         .navigationDestination(for: PersistentIdentifier.self) { rideID in
            RideRouteDetailView(rideDetailViewModel: rideDetailViewModel, rideID: rideID)
               .onDisappear { loadHeroRoute() }
         }
      }
      .onAppear {
         rideHistoryViewModel.load()
         loadHeroRoute()
      }
   }

   // MARK: - List

   private var rideList: some View {
      ScrollView {
         LazyVStack(spacing: 12) {
            if let summary = rideHistoryViewModel.summary {
               RideHistorySummaryStrip(summary: summary)
            }

            if let latest = rideHistoryViewModel.latestRow {
               NavigationLink(value: latest.id) {
                  RideHistoryHeroCard(
                     row: latest,
                     distanceUnit: rideHistoryViewModel.distanceUnit,
                     route: rideRouteViewModel.route,
                     isRouteLoaded: rideRouteViewModel.isLoaded
                  )
               }
               .buttonStyle(.plain)
               .contextMenu { deleteButton(for: latest) }
            }

            if !rideHistoryViewModel.olderRows.isEmpty {
               Text("EARLIER")
                  .font(.caption2.weight(.bold))
                  .kerning(1.4)
                  .foregroundStyle(.white.opacity(0.4))
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.top, 8)
                  .padding(.leading, 4)
            }

            ForEach(rideHistoryViewModel.olderRows) { row in
               NavigationLink(value: row.id) {
                  RideHistoryRideCard(row: row, distanceUnit: rideHistoryViewModel.distanceUnit)
               }
               .buttonStyle(.plain)
               .contextMenu { deleteButton(for: row) }
            }
         }
         .padding(.horizontal, 16)
         .padding(.bottom, 24)
      }
      .scrollIndicators(.hidden)
      .confirmationDialog(
         deletionTitle,
         isPresented: isConfirmingDeletion,
         titleVisibility: .visible
      ) {
         Button(deletionConfirmLabel, role: .destructive) {
            rideHistoryViewModel.delete(ids: Set(pendingDeletion.map(\.id)))
            pendingDeletion = []
            loadHeroRoute()
         }

         Button("Keep", role: .cancel) {
            pendingDeletion = []
         }
      } message: {
         Text("This also deletes its recorded route and cannot be undone.")
      }
   }

   // MARK: - Hero Route

   private func loadHeroRoute() {
      rideRouteViewModel.load(rideHistoryViewModel.latestRow?.id)
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
