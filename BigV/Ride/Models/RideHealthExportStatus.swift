//
//  RideHealthExportStatus.swift
//  BigV
//

import Foundation

/// Outcome of projecting a finished ride into Apple Health.
///
/// Every case other than `.saved` is survivable: BigV is the system of record,
/// so the ride is already safe on disk regardless of what Health does.
enum RideHealthExportStatus: String, Sendable, Equatable {

   /// Nothing to report yet, or nothing worth exporting.
   case idle

   case exporting
   case saved

   /// The rider declined to share workouts.
   case denied

   /// Health data is not available on this device.
   case unavailable

   case failed
}
