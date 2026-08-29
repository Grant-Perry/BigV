//
//  RideSettingsView.swift
//  BigV
//

import SwiftUI

/// The Settings tab, and the first thing a new rider sees.
///
/// Deliberately small: the units choice drives every measurement in the app —
/// dashboard, map, radar, history, summary and the Watch mirror — so it lives
/// here rather than scattered through feature sheets. On first launch the tab
/// bar lands here and a Start Riding button sends the rider on their way.
struct RideSettingsView: View {

   @Bindable var unitsSettings: RideUnitsSettings
   let onShowRadar: () -> Void
   let onFinishSetup: () -> Void

   var body: some View {
      NavigationStack {
         ScrollView {
            VStack(spacing: 12) {
               if !unitsSettings.hasCompletedSetup {
                  header
               }

               unitsCard

               temperatureCard

               radarCard
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
         Image(systemName: "bicycle")
            .font(.system(size: 34, weight: .semibold))
            .foregroundStyle(RideChromeTokens.ice)

         Text("A couple of choices and the cockpit is yours.")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.55))
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
            .foregroundStyle(.white.opacity(0.4))
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
            .foregroundStyle(.white.opacity(0.4))
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
               .foregroundStyle(RideChromeTokens.ice)

            VStack(alignment: .leading, spacing: 2) {
               Text("Rear Radar")
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(.white)

               Text("Pair a Garmin Varia or compatible radar")
                  .font(.caption)
                  .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Image(systemName: "chevron.right")
               .font(.caption.weight(.semibold))
               .foregroundStyle(.white.opacity(0.3))
         }
         .padding(14)
         .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .rideGlassCard()
      .accessibilityIdentifier("setup.button.radar")
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
         .foregroundStyle(.white.opacity(0.45))
   }
}

#Preview {
   RideSettingsView(unitsSettings: RideUnitsSettings(), onShowRadar: {}, onFinishSetup: {})
      .preferredColorScheme(.dark)
}
