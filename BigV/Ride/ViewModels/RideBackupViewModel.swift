//
//  RideBackupViewModel.swift
//  BigV
//

import Foundation

/// Coordinates Settings backup export/import and surfaces status to the view.
@Observable
@MainActor
final class RideBackupViewModel {

   // MARK: - State

   private(set) var statusMessage: String?
   private(set) var isBusy = false

   /// Set when a backup file is ready to share; cleared after the share sheet.
   var shareURL: URL?

   // MARK: - Dependencies

   private let backupManager: RideBackupManager
   private let isRideInProgress: () -> Bool
   private let onHistoryChanged: () -> Void

   // MARK: - Initialization

   init(
      backupManager: RideBackupManager,
      isRideInProgress: @escaping () -> Bool,
      onHistoryChanged: @escaping () -> Void
   ) {
      self.backupManager = backupManager
      self.isRideInProgress = isRideInProgress
      self.onHistoryChanged = onHistoryChanged
   }

   // MARK: - Intent

   func exportBackup() {
      guard !isBusy else { return }
      isBusy = true
      statusMessage = nil

      do {
         let result = try backupManager.exportBackup()
         shareURL = result.url
         statusMessage = result.rideCount == 0
            ? "Backup ready — preferences only (no finished rides yet)."
            : "Backup ready — \(result.rideCount) ride\(result.rideCount == 1 ? "" : "s")."
      } catch {
         statusMessage = error.localizedDescription
         shareURL = nil
      }

      isBusy = false
   }

   func importBackup(from url: URL) {
      guard !isBusy else { return }
      isBusy = true
      statusMessage = nil

      do {
         let result = try backupManager.importBackup(
            from: url,
            rideInProgress: isRideInProgress()
         )
         onHistoryChanged()
         statusMessage =
            "Restored \(result.addedRideCount) ride\(result.addedRideCount == 1 ? "" : "s")"
            + (result.skippedRideCount > 0
               ? ", skipped \(result.skippedRideCount) already here."
               : ".")
      } catch {
         statusMessage = error.localizedDescription
      }

      isBusy = false
   }

   func clearShareURL() {
      shareURL = nil
   }

   func reportFailure(_ message: String) {
      statusMessage = message
   }
}
