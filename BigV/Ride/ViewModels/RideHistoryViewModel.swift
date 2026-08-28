//
//  RideHistoryViewModel.swift
//  BigV
//

import Foundation
import SwiftData

/// Presents saved rides and forwards deletion to storage.
@Observable
@MainActor
final class RideHistoryViewModel {

   // MARK: - Row

   struct Row: Identifiable, Sendable, Equatable {
      let id: PersistentIdentifier
      let dateText: String
      let distanceText: String
      let durationText: String
      let averageSpeedText: String
      let maximumSpeedText: String
      let elevationGainText: String
      let speedUnit: String
      let distanceUnit: String
   }

   // MARK: - State

   private(set) var rows: [Row] = []

   var isEmpty: Bool { rows.isEmpty }

   var latestRow: Row? { rows.first }

   var olderRows: [Row] { Array(rows.dropFirst()) }

   var distanceUnit: String { RideUnitSystem.current.distanceUnit }

   // MARK: - Dependencies

   private let rideStorageManager: RideStorageManager

   // MARK: - Private State

   private var rides: [Ride] = []

   // MARK: - Initialization

   init(rideStorageManager: RideStorageManager) {
      self.rideStorageManager = rideStorageManager
   }

   // MARK: - Intent

   func load() {
      rides = rideStorageManager.savedRides()
      rows = rides.map(Self.row)
   }

   /// Rows the rider swiped, awaiting explicit confirmation.
   ///
   /// Deleting a ride destroys its samples too and cannot be undone, so a swipe
   /// alone must never be enough to lose one.
   func rows(at offsets: IndexSet) -> [Row] {
      offsets.compactMap { rows.indices.contains($0) ? rows[$0] : nil }
   }

   func delete(ids: Set<PersistentIdentifier>) {
      guard !ids.isEmpty else { return }

      for ride in rides where ids.contains(ride.persistentModelID) {
         rideStorageManager.delete(ride)
      }

      load()
   }

   // MARK: - Mapping

   private static func row(for ride: Ride) -> Row {
      // Rows snapshot the system at load; `load()` runs on every appearance,
      // so a units change in setup is picked up the next time history opens.
      let system = RideUnitSystem.current
      return Row(
         id: ride.persistentModelID,
         dateText: ride.startDate.formatted(date: .abbreviated, time: .shortened),
         distanceText: RideFormatters.distance(ride.distance, system: system),
         durationText: RideFormatters.duration(ride.duration),
         averageSpeedText: RideFormatters.speed(ride.averageSpeed, system: system),
         maximumSpeedText: RideFormatters.speed(ride.maximumSpeed, system: system),
         elevationGainText: RideFormatters.elevationGain(ride.elevationGain, system: system),
         speedUnit: system.speedUnit,
         distanceUnit: system.distanceUnit
      )
   }
}
