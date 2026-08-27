//
//  RideHistoryView.swift
//  BigV
//

import SwiftData
import SwiftUI

/// Saved rides, newest first. Reachable only while idle so it never competes
/// with the live riding screen.
struct RideHistoryView: View {

   let rideHistoryViewModel: RideHistoryViewModel
   let rideRouteViewModel: RideRouteViewModel

   @Environment(\.dismiss) private var dismiss

   @State private var pendingDeletion: [RideHistoryViewModel.Row] = []

   var body: some View {
      NavigationStack {
         ZStack {
            Color.black.ignoresSafeArea()

            if rideHistoryViewModel.isEmpty {
               emptyState
            } else {
               rideList
            }
         }
         .navigationTitle("Rides")
         .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
               Button("Done") { dismiss() }
            }
         }
         .navigationDestination(for: PersistentIdentifier.self) { rideID in
            RideRouteDetailView(rideRouteViewModel: rideRouteViewModel, rideID: rideID)
         }
      }
      .onAppear { rideHistoryViewModel.load() }
   }

   // MARK: - List

   private var rideList: some View {
      List {
         ForEach(rideHistoryViewModel.rows) { row in
            NavigationLink(value: row.id) {
               RideHistoryRowView(row: row, distanceUnit: rideHistoryViewModel.distanceUnit)
            }
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(.white.opacity(0.12))
         }
         .onDelete { offsets in
            pendingDeletion = rideHistoryViewModel.rows(at: offsets)
         }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .confirmationDialog(
         deletionTitle,
         isPresented: isConfirmingDeletion,
         titleVisibility: .visible
      ) {
         Button(deletionConfirmLabel, role: .destructive) {
            rideHistoryViewModel.delete(ids: Set(pendingDeletion.map(\.id)))
            pendingDeletion = []
         }

         Button("Keep", role: .cancel) {
            pendingDeletion = []
         }
      } message: {
         Text("This also deletes its recorded route and cannot be undone.")
      }
   }

   // MARK: - Deletion Confirmation

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

   // MARK: - Empty State

   private var emptyState: some View {
      ContentUnavailableView(
         "No Rides Yet",
         systemImage: .bicycleIcon,
         description: Text("Finished rides are saved here automatically.")
      )
      .foregroundStyle(.white.opacity(0.7))
   }
}

// MARK: - Row

private struct RideHistoryRowView: View {

   let row: RideHistoryViewModel.Row
   let distanceUnit: String

   var body: some View {
      HStack(alignment: .firstTextBaseline) {
         Text(row.dateText)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)

         Spacer(minLength: 12)

         Text("\(row.distanceText) \(distanceUnit)")
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.8))

         Text(row.durationText)
            .font(.caption.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.45))
            .frame(minWidth: 52, alignment: .trailing)
      }
      .padding(.vertical, 6)
   }
}

// MARK: - Icons

private extension String {
   static let bicycleIcon = "bicycle"
}
