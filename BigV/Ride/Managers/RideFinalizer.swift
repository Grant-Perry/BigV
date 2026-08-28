//
//  RideFinalizer.swift
//  BigV
//

import Foundation
import SwiftData

/// Runs the end-of-ride pipeline: close the stored ride, then project it into
/// Apple Health and link the workout back.
///
/// Split out of `RideSessionManager` so the live recording path and the commit
/// path stop sharing a type. Everything that happens *after* the wheels stop
/// lands here — a Watch-coordinated workout, a second export destination, a GPX
/// or FIT writer — and none of it belongs beside the location stream.
///
/// Reports results rather than writing them. `RideSessionManager` stays the only
/// thing in the app allowed to publish `RideState`.
@MainActor
struct RideFinalizer {

   // MARK: - Results

   /// What closing the stored ride produced.
   struct Commit {

      /// `nil` when the store rejected the ride, so there is nothing to export.
      let ride: Ride?
      let hasStorageFailure: Bool
   }

   /// What the Health export produced.
   struct Export {

      let status: RideHealthExportStatus
      let hasStorageFailure: Bool
   }

   // MARK: - Dependencies

   /// Both optional so previews and engine tests can build a session with no
   /// side effects.
   private let rideStorageManager: RideStorageManager?
   private let rideHealthManager: RideHealthManager?

   // MARK: - Initialization

   init(
      rideStorageManager: RideStorageManager? = nil,
      rideHealthManager: RideHealthManager? = nil
   ) {
      self.rideStorageManager = rideStorageManager
      self.rideHealthManager = rideHealthManager
   }

   // MARK: - Capability

   /// Whether a committed ride has anywhere to export to. Callers gate on this
   /// so a session without Health never advertises an export that cannot run.
   var exportsToHealth: Bool { rideHealthManager != nil }

   private var hasStorageFailure: Bool { rideStorageManager?.hasFailure ?? false }

   // MARK: - Commit

   /// Closes out the stored ride. `nil` means there is no store behind this
   /// session at all, which is different from a store that rejected the ride.
   func commit(_ state: RideState) -> Commit? {
      guard let rideStorageManager else { return nil }

      let ride = rideStorageManager.finalizeRide(with: state)

      return Commit(ride: ride, hasStorageFailure: rideStorageManager.hasFailure)
   }

   // MARK: - Export

   /// Writes the committed ride to Apple Health and records the workout link.
   ///
   /// Every failure mode is survivable: the ride is already persisted, so a
   /// denial or a write error costs the export, never the ride.
   func export(_ ride: Ride) async -> Export {
      guard let rideHealthManager else {
         return Export(status: .unavailable, hasStorageFailure: hasStorageFailure)
      }

      let status: RideHealthExportStatus

      switch await rideHealthManager.export(ride) {
         case .saved(let identifier):
            rideStorageManager?.linkHealthKitWorkout(identifier, to: ride)
            status = .saved

         case .denied:
            status = .denied

         case .unavailable:
            status = .unavailable

         case .failed:
            status = .failed
      }

      return Export(status: status, hasStorageFailure: hasStorageFailure)
   }

   // MARK: - Authorization

   /// Asks once, in context, while the rider is waiting for a GPS fix.
   func requestHealthAuthorization() async {
      await rideHealthManager?.requestAuthorizationIfNeeded()
   }
}
