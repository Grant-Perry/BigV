//
//  RideSettingsView.swift
//  BigV
//

import SwiftData
import SwiftUI

/// The Settings tab, and the first thing a new rider sees after onboarding.
///
/// Laid out as groups a rider can take in without scrolling to find them: what
/// the numbers read in, how the cockpit is lit, what it does on its own while
/// riding, then the account. Each group is its own view, so this one only
/// decides what appears and in what order.
///
/// Every choice with a handful of options is a segmented control rather than a
/// list of rows — the whole choice stays on one line, and a card that used to
/// run three hundred points now runs a hundred and fifty.
struct RideSettingsView: View {

   @Bindable var unitsSettings: RideUnitsSettings
   @Bindable var onboardingSettings: RideOnboardingSettings
   @Bindable var plusStore: BigVeloPlusStore
   @Bindable var backupViewModel: RideBackupViewModel
   @Bindable var climbSettings: RideClimbSettings
   @Bindable var lapSettings: RideLapSettings
   @Bindable var appearanceSettings: RideAppearanceSettings
   let cockpitLayoutSettings: RideCockpitLayoutSettings
   let onShowRadar: () -> Void
   let onFinishSetup: () -> Void

   var body: some View {
      NavigationStack {
         ScrollView {
            VStack(spacing: 12) {
               if !unitsSettings.hasCompletedSetup {
                  header
               }

               RideSettingsUnitsCard(unitsSettings: unitsSettings)

               RideSettingsAppearanceCard(appearanceSettings: appearanceSettings)

               RideSettingsRidingCard(
                  unitsSettings: unitsSettings,
                  climbSettings: climbSettings,
                  lapSettings: lapSettings,
                  cockpitLayoutSettings: cockpitLayoutSettings,
                  onShowRadar: onShowRadar
               )

               RideSettingsPlusCard(plusStore: plusStore)

               // Nothing to back up and nothing worth replaying until the rider
               // is out of setup, so both stay out of the first run.
               if unitsSettings.hasCompletedSetup {
                  RideSettingsBackupCard(backupViewModel: backupViewModel)

                  onboardingResetCard
               }
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
      }
   }

   // MARK: - Header

   private var header: some View {
      VStack(spacing: 8) {
         RideWordmark(pointSize: 36)

         Text("A couple of choices and the cockpit is yours.")
            .font(.footnote)
            .foregroundStyle(RideDashboardTheme.ink(0.55))
            .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 6)
   }

   // MARK: - Onboarding Reset

   /// Headerless, and the only row on the page that keeps a glyph: a standalone
   /// action card has no neighbouring rows to line its title up with.
   private var onboardingResetCard: some View {
      RideSettingsCard {
         RideSettingsNavRow(
            symbolName: "arrow.counterclockwise",
            title: "Reset Onboarding",
            detail: "Show the kit, radar, road, story and Keep BigVelo screens again",
            tint: RideDashboardTheme.ember,
            showsChevron: false,
            identifier: "settings.button.resetOnboarding"
         ) {
            onboardingSettings.resetOnboarding()
         }
      }
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
         onboardingSettings: onboarding,
         cockpitLayoutSettings: RideCockpitLayoutSettings()
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
      cockpitLayoutSettings: RideCockpitLayoutSettings(),
      onShowRadar: {},
      onFinishSetup: {}
   )
   .preferredColorScheme(.dark)
}
