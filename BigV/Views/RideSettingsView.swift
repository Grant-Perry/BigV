//
//  RideSettingsView.swift
//  BigV
//

import StoreKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The Settings tab, and the first thing a new rider sees after onboarding.
///
/// Deliberately small: the units choice drives every measurement in the app —
/// dashboard, map, radar, history, summary and the Watch mirror — so it lives
/// here rather than scattered through feature sheets. On first launch the tab
/// bar lands here and a Start Riding button sends the rider on their way.
struct RideSettingsView: View {

   @Bindable var unitsSettings: RideUnitsSettings
   @Bindable var onboardingSettings: RideOnboardingSettings
   @Bindable var plusStore: BigVeloPlusStore
   @Bindable var backupViewModel: RideBackupViewModel
   @Bindable var climbSettings: RideClimbSettings
   @Bindable var lapSettings: RideLapSettings
   @Bindable var appearanceSettings: RideAppearanceSettings
   let onShowRadar: () -> Void
   let onFinishSetup: () -> Void

   @Environment(\.openURL) private var openURL
   @State private var isShowingRedeem = false
   @State private var isShowingImporter = false
   @State private var isConfirmingRestore = false

   private let privacyURL = URL(string: "https://bigvelo.app/privacy")!
   private let termsURL = URL(string: "https://bigvelo.app/terms")!

   var body: some View {
      NavigationStack {
         ScrollView {
            VStack(spacing: 12) {
               if !unitsSettings.hasCompletedSetup {
                  header
               }

               unitsCard

               temperatureCard

               appearanceCard

               radarCard

               ridingCard

               plusCard

               backupCard

               onboardingCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
         }
         .scrollIndicators(.hidden)
         .safeAreaInset(edge: .bottom, spacing: 0) {
            if !unitsSettings.hasCompletedSetup {
               startRidingButton
            }
         }
         // A background rather than a ZStack sibling: a full-bleed layer inside
         // a stack inflates the stack past the safe area and the scroll view
         // loses its navigation-bar and footer insets.
         .background {
            RideAtmosphereBackground()
               .ignoresSafeArea()
         }
         .rideAppFooter()
         .navigationTitle(unitsSettings.hasCompletedSetup ? "Settings" : "Ride Setup")
         .navigationBarTitleDisplayMode(.large)
         .offerCodeRedemption(isPresented: $isShowingRedeem) { _ in
            Task { await plusStore.refreshEntitlement() }
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
         .task {
            await plusStore.loadProducts()
         }
      }
   }

   // MARK: - Header

   private var header: some View {
      VStack(spacing: 8) {
         Image(systemName: "bicycle")
            .font(.system(size: 34, weight: .semibold))
            .foregroundStyle(RideDashboardTheme.ice)

         Text("A couple of choices and the cockpit is yours.")
            .font(.footnote)
            .foregroundStyle(RideDashboardTheme.ink(0.55))
            .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 6)
   }

   // MARK: - Units

   private var unitsCard: some View {
      VStack(alignment: .leading, spacing: 10) {
         cardHeader("UNITS")

         ForEach(RideUnitSystem.allCases) { system in
            RideSetupChoiceRow(
               title: system.title,
               detail: system.exampleText,
               isSelected: unitsSettings.system == system,
               identifier: "setup.units.\(system.rawValue)"
            ) {
               unitsSettings.system = system
            }
         }

         Text("Applies everywhere — speed, distance, elevation, radar ranges, history and your Watch.")
            .font(.caption2)
            .foregroundStyle(RideDashboardTheme.ink(0.4))
      }
      .padding(14)
      .rideGlassCard()
   }

   // MARK: - Temperature

   /// Kept apart from the measurement system on purpose: riders routinely want
   /// miles with a Celsius sky, or the reverse.
   private var temperatureCard: some View {
      VStack(alignment: .leading, spacing: 10) {
         cardHeader("TEMPERATURE")

         ForEach(RideTemperatureUnit.allCases) { unit in
            RideSetupChoiceRow(
               title: unit.title,
               detail: unit.exampleText,
               isSelected: unitsSettings.temperatureUnit == unit,
               identifier: "setup.temperature.\(unit.rawValue)"
            ) {
               unitsSettings.temperatureUnit = unit
            }
         }

         Text("Used by the weather chip and the forecast.")
            .font(.caption2)
            .foregroundStyle(RideDashboardTheme.ink(0.4))
      }
      .padding(14)
      .rideGlassCard()
   }

   // MARK: - Appearance

   /// Day, night, or the phone's call. The speedometer carries a one-tap
   /// flip between the first two; Automatic is only offered here.
   private var appearanceCard: some View {
      VStack(alignment: .leading, spacing: 10) {
         cardHeader("APPEARANCE")

         ForEach(RideAppearanceMode.allCases) { mode in
            RideSetupChoiceRow(
               title: mode.title,
               detail: mode.detail,
               isSelected: appearanceSettings.mode == mode,
               identifier: "setup.appearance.\(mode.rawValue)"
            ) {
               withAnimation(.easeInOut(duration: 0.25)) {
                  appearanceSettings.mode = mode
               }
            }
         }

         Text("Day is for the sun. The sun-and-moon chip on the speedometer switches between Day and Night without coming back here.")
            .font(.caption2)
            .foregroundStyle(RideDashboardTheme.ink(0.4))
      }
      .padding(14)
      .rideGlassCard()
   }

   // MARK: - Radar

   private var radarCard: some View {
      Button(action: onShowRadar) {
         HStack(spacing: 12) {
            Image(systemName: "car.rear.waves.up")
               .font(.title3.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ice)

            VStack(alignment: .leading, spacing: 2) {
               Text("Rear Radar")
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(RideDashboardTheme.ink)

               Text("Varia™ rear radar compatible")
                  .font(.caption)
                  .foregroundStyle(RideDashboardTheme.ink(0.55))
            }

            Spacer()

            Image(systemName: "chevron.right")
               .font(.caption.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ink(0.3))
         }
         .padding(14)
         .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .rideGlassCard()
      .accessibilityIdentifier("setup.button.radar")
   }

   // MARK: - Riding

   /// Climb auto-switch and auto-lap, together: both are about what the
   /// cockpit does on its own while the rider keeps their hands on the bars.
   private var ridingCard: some View {
      VStack(alignment: .leading, spacing: 12) {
         cardHeader("RIDING")

         Toggle(isOn: $climbSettings.autoSwitchEnabled) {
            VStack(alignment: .leading, spacing: 2) {
               Text("Climb Page Auto-Switch")
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(RideDashboardTheme.ink)

               Text("Jump to the climb page when a categorized climb starts")
                  .font(.caption)
                  .foregroundStyle(RideDashboardTheme.ink(0.55))
            }
         }
         .tint(RideDashboardTheme.ember)
         .accessibilityIdentifier("settings.toggle.climbAutoSwitch")

         VStack(alignment: .leading, spacing: 6) {
            Text("Auto-Lap")
               .font(.subheadline.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ink)

            Picker("Auto-Lap", selection: $lapSettings.autoLapUnits) {
               ForEach(RideLapSettings.autoLapChoices, id: \.self) { choice in
                  Text(autoLapLabel(for: choice)).tag(choice)
               }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.picker.autoLap")

            Text("Cut a lap automatically every so many \(unitsSettings.system == .imperial ? "miles" : "kilometers"). The LAP button works either way.")
               .font(.caption2)
               .foregroundStyle(RideDashboardTheme.ink(0.4))
         }
      }
      .padding(14)
      .rideGlassCard()
   }

   private func autoLapLabel(for choice: Double) -> String {
      choice == 0 ? "Off" : choice.formatted(.number.precision(.fractionLength(0)))
   }

   // MARK: - Plus

   private var plusCard: some View {
      VStack(alignment: .leading, spacing: 12) {
         cardHeader("BIGVELO")

         HStack {
            Text(plusStore.accessHeadline)
               .font(.subheadline.weight(.semibold))
               .foregroundStyle(plusStore.isPlus ? RideDashboardTheme.go : RideDashboardTheme.ink)

            Spacer()

            if plusStore.isPlus {
               Image(systemName: "checkmark.seal.fill")
                  .foregroundStyle(RideDashboardTheme.go)
            }
         }

         Text(plusStore.accessDetail)
            .font(.caption2)
            .foregroundStyle(RideDashboardTheme.ink(0.45))

         if !plusStore.isPlus {
            RidePlusPricingCard(plusStore: plusStore, accessibilityPrefix: "settings")
         }

         HStack(spacing: 12) {
            Button("Restore") {
               Task { await plusStore.restore() }
            }
            .buttonStyle(.bordered)

            Button("Redeem Code") {
               isShowingRedeem = true
            }
            .buttonStyle(.bordered)

            Spacer()
         }
         .tint(RideDashboardTheme.ice)

         #if DEBUG
         Toggle("Force Plus (Debug)", isOn: $plusStore.forcePlusInDebug)
            .font(.caption)
            .foregroundStyle(RideDashboardTheme.ink(0.7))
            .tint(RideDashboardTheme.ember)
         #endif

         HStack(spacing: 16) {
            Button("Privacy") { openURL(privacyURL) }
            Button("Terms") { openURL(termsURL) }
         }
         .font(.caption.weight(.semibold))
         .foregroundStyle(RideDashboardTheme.ink(0.55))

         if let message = plusStore.lastErrorMessage {
            Text(message)
               .font(.caption2)
               .foregroundStyle(RideDashboardTheme.halt)
         }
      }
      .padding(14)
      .rideGlassCard()
   }

   // MARK: - Backup

   private var backupCard: some View {
      VStack(alignment: .leading, spacing: 12) {
         cardHeader("BACKUP")

         Text("A BigVelo backup is rides plus preferences, for this app. To open one ride in another app, export GPX from that ride’s story.")
            .font(.caption2)
            .foregroundStyle(RideDashboardTheme.ink(0.45))

         HStack(spacing: 12) {
            Button {
               backupViewModel.exportBackup()
            } label: {
               Label("Backup", systemImage: "arrow.up.doc")
            }
            .buttonStyle(.bordered)
            .disabled(backupViewModel.isBusy)
            .accessibilityIdentifier("settings.button.backup")

            Button {
               isConfirmingRestore = true
            } label: {
               Label("Restore", systemImage: "arrow.down.doc")
            }
            .buttonStyle(.bordered)
            .disabled(backupViewModel.isBusy)
            .accessibilityIdentifier("settings.button.restore")

            Spacer()
         }
         .tint(RideDashboardTheme.ice)

         if let url = backupViewModel.shareURL {
            ShareLink(
               item: url,
               preview: SharePreview("BigVelo Backup", image: Image(systemName: "bicycle"))
            ) {
               Label("Share Backup File…", systemImage: "square.and.arrow.up")
                  .font(.subheadline.weight(.semibold))
            }
            .accessibilityIdentifier("settings.button.shareBackup")
         }

         if let message = backupViewModel.statusMessage {
            Text(message)
               .font(.caption2)
               .foregroundStyle(RideDashboardTheme.ink(0.55))
         }
      }
      .padding(14)
      .rideGlassCard()
   }

   // MARK: - Onboarding Reset

   private var onboardingCard: some View {
      Button {
         onboardingSettings.resetOnboarding()
      } label: {
         HStack(spacing: 12) {
            Image(systemName: "arrow.counterclockwise")
               .font(.title3.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ember)

            VStack(alignment: .leading, spacing: 2) {
               Text("Reset Onboarding")
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(RideDashboardTheme.ink)

               Text("Show the kit, radar, road, story and Keep BigVelo screens again")
                  .font(.caption)
                  .foregroundStyle(RideDashboardTheme.ink(0.55))
            }

            Spacer()
         }
         .padding(14)
         .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .rideGlassCard()
      .accessibilityIdentifier("settings.button.resetOnboarding")
   }

   // MARK: - First Run

   /// Pinned rather than scrolled, and only ever shown once. Afterwards the tab
   /// bar is the way out, and a button that just switches tabs is furniture.
   private var startRidingButton: some View {
      Button("Start Riding") {
         unitsSettings.hasCompletedSetup = true
         onFinishSetup()
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.extraLarge)
      .tint(RideDashboardTheme.go)
      .font(.headline)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 16)
      .padding(.top, 12)
      .padding(.bottom, 4)
      // Cards scroll underneath, so the pinned action needs its own ground.
      .background {
         LinearGradient(
            colors: [RideDashboardTheme.void.opacity(0), RideDashboardTheme.void.opacity(0.92)],
            startPoint: .top,
            endPoint: .bottom
         )
         .ignoresSafeArea()
      }
      .accessibilityIdentifier("setup.button.done")
   }

   // MARK: - Pieces

   private func cardHeader(_ title: String) -> some View {
      Text(title)
         .font(.caption2.weight(.bold))
         .kerning(1.2)
         .foregroundStyle(RideDashboardTheme.ink(0.45))
   }

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

#Preview {
   let container = try! ModelContainer(
      for: Schema([Ride.self, RideSample.self, RideRadarEvent.self]),
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
   )
   let storage = RideStorageManager(modelContext: container.mainContext)
   let units = RideUnitsSettings()
   let onboarding = RideOnboardingSettings()
   let radar = RideRadarSettings()
   let backup = RideBackupViewModel(
      backupManager: RideBackupManager(
         rideStorageManager: storage,
         unitsSettings: units,
         radarSettings: radar,
         onboardingSettings: onboarding
      ),
      isRideInProgress: { false },
      onHistoryChanged: {}
   )

   return RideSettingsView(
      unitsSettings: units,
      onboardingSettings: onboarding,
      plusStore: BigVeloPlusStore(),
      backupViewModel: backup,
      climbSettings: RideClimbSettings(),
      lapSettings: RideLapSettings(),
      appearanceSettings: RideAppearanceSettings(),
      onShowRadar: {},
      onFinishSetup: {}
   )
   .preferredColorScheme(.dark)
}
