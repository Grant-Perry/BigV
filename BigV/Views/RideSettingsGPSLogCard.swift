//
//  RideSettingsGPSLogCard.swift
//  BigV
//

import SwiftUI

/// The GPS LOG section of Settings: the switch for the per-ride diagnostic
/// file, and a way to send or delete the ones on this device.
struct RideSettingsGPSLogCard: View {

   @Bindable var gpsLogStore: RideFixLogStore

   @State private var isConfirmingDelete = false

   var body: some View {
      RideSettingsCard(
         title: "GPS LOG",
         footnote: "Keeps a text file of every GPS fix and receiver event for each ride (last 5 rides). Share it if a speed or distance looks wrong."
      ) {
         RideSettingsToggleRow(
            title: "Record GPS log",
            detail: "One small file per ride, stored on this device",
            isOn: $gpsLogStore.isEnabled,
            identifier: "settings.toggle.gpsLog"
         )

         if let newest = gpsLogStore.latestLogURL {
            ShareLink(item: newest) {
               Label("Share GPS log", systemImage: "square.and.arrow.up")
                  .font(.caption.weight(.semibold))
            }
            .tint(RideDashboardTheme.ice)
            .accessibilityIdentifier("settings.button.shareGPSLog")

            if gpsLogStore.logFileURLs.count > 1 {
               ShareLink(items: Array(gpsLogStore.logFileURLs.prefix(RideFixLogStore.keptFileCount))) {
                  Label("Share last \(min(gpsLogStore.logFileURLs.count, RideFixLogStore.keptFileCount)) logs", systemImage: "square.and.arrow.up.on.square")
                     .font(.caption.weight(.semibold))
               }
               .tint(RideDashboardTheme.ice)
               .accessibilityIdentifier("settings.button.shareGPSLogs")
            }

            Button(role: .destructive) {
               isConfirmingDelete = true
            } label: {
               Label("Delete all logs", systemImage: "trash")
                  .font(.caption.weight(.semibold))
            }
            .tint(RideDashboardTheme.halt)
            .accessibilityIdentifier("settings.button.deleteGPSLogs")
         } else {
            Text("No log yet — start a ride.")
               .font(.caption2)
               .foregroundStyle(RideDashboardTheme.ink(0.55))
         }
      }
      .task { await gpsLogStore.refreshForDisplay() }
      .confirmationDialog(
         "Delete all log files?",
         isPresented: $isConfirmingDelete,
         titleVisibility: .visible
      ) {
         Button("Delete All Logs", role: .destructive) {
            Task { await gpsLogStore.deleteAllLogs() }
         }

         Button("Keep", role: .cancel) {}
      } message: {
         Text("All logs removes every log file from this device. A ride that’s recording starts a fresh log.")
      }
   }
}
