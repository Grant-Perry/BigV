//
//  RideSettingsBackupCard.swift
//  BigV
//

import SwiftUI
import UniformTypeIdentifiers

/// The BACKUP section of Settings: write the whole library out, or read one in.
///
/// Its own view because restoring is a three-step conversation — confirm, pick
/// a file, report — and all three belong next to the buttons that start it.
struct RideSettingsBackupCard: View {

   @Bindable var backupViewModel: RideBackupViewModel

   @State private var isShowingImporter = false
   @State private var isConfirmingRestore = false

   var body: some View {
      RideSettingsCard(
         title: "BACKUP",
         footnote: "A backup is every ride plus your preferences, for this app. To open a single ride somewhere else, export GPX from that ride’s story."
      ) {
         HStack(spacing: 8) {
            Button {
               backupViewModel.exportBackup()
            } label: {
               Label("Backup", systemImage: "arrow.up.doc")
            }
            .disabled(backupViewModel.isBusy)
            .accessibilityIdentifier("settings.button.backup")

            Button {
               isConfirmingRestore = true
            } label: {
               Label("Restore", systemImage: "arrow.down.doc")
            }
            .disabled(backupViewModel.isBusy)
            .accessibilityIdentifier("settings.button.restore")

            Spacer(minLength: 0)

            if backupViewModel.isBusy {
               ProgressView()
                  .controlSize(.small)
                  .tint(RideDashboardTheme.ink(0.6))
            }
         }
         .buttonStyle(.bordered)
         .controlSize(.small)
         .font(.caption.weight(.semibold))
         .tint(RideDashboardTheme.ice)

         if let url = backupViewModel.shareURL {
            ShareLink(
               item: url,
               preview: SharePreview("BigVelo Backup", image: Image(systemName: "bicycle"))
            ) {
               Label("Share Backup File…", systemImage: "square.and.arrow.up")
                  .font(.caption.weight(.semibold))
            }
            .tint(RideDashboardTheme.ice)
            .accessibilityIdentifier("settings.button.shareBackup")
         }

         if let message = backupViewModel.statusMessage {
            Text(message)
               .font(.caption2)
               .foregroundStyle(RideDashboardTheme.ink(0.55))
               .fixedSize(horizontal: false, vertical: true)
         }
      }
      .fileImporter(
         isPresented: $isShowingImporter,
         allowedContentTypes: [.json],
         allowsMultipleSelection: false
      ) { result in
         handleImportResult(result)
      }
      .confirmationDialog(
         "Restore Backup?",
         isPresented: $isConfirmingRestore,
         titleVisibility: .visible
      ) {
         Button("Choose Backup File…") {
            isShowingImporter = true
         }

         Button("Cancel", role: .cancel) {}
      } message: {
         Text("Preferences replace what’s here. Finished rides that aren’t already saved are added; duplicates are skipped. End any active ride first.")
      }
   }

   // MARK: - Import

   private func handleImportResult(_ result: Result<[URL], Error>) {
      switch result {
         case .success(let urls):
            guard let url = urls.first else { return }
            backupViewModel.importBackup(from: url)

         case .failure(let error):
            backupViewModel.reportFailure(error.localizedDescription)
      }
   }
}
