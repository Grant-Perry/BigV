//
//  RideSetupView.swift
//  BigV
//

import SwiftUI

/// First-run setup and the app's global settings surface.
///
/// Shown automatically once on first launch and reachable any time from the
/// gear on the dashboard status row. Deliberately small: the units choice
/// drives every measurement in the app — dashboard, map, radar, history,
/// summary and the Watch mirror — so it lives here, not in a feature sheet.
struct RideSetupView: View {

   @Bindable var unitsSettings: RideUnitsSettings
   let onShowRadar: () -> Void

   @Environment(\.dismiss) private var dismiss

   var body: some View {
      NavigationStack {
         ZStack {
            RideAtmosphereBackground()
               .ignoresSafeArea()

            ScrollView {
               VStack(spacing: 12) {
                  header

                  unitsCard

                  radarCard

                  footnote
               }
               .padding(.horizontal, 16)
               .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
         }
         .navigationTitle("Ride Setup")
         .navigationBarTitleDisplayMode(.large)
         .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
               Button("Done") { finish() }
                  .accessibilityIdentifier("setup.button.done")
            }
         }
      }
      .preferredColorScheme(.dark)
      .interactiveDismissDisabled(false)
      .onDisappear { unitsSettings.hasCompletedSetup = true }
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
            unitOption(system)
         }

         Text("Applies everywhere — speed, distance, elevation, radar ranges, history and your Watch.")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.4))
      }
      .padding(14)
      .rideGlassCard()
   }

   private func unitOption(_ system: RideUnitSystem) -> some View {
      let isSelected = unitsSettings.system == system

      return Button {
         unitsSettings.system = system
      } label: {
         HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
               Text(system.title)
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(.white)

               Text(system.exampleText)
                  .font(.caption)
                  .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
               .font(.title3)
               .foregroundStyle(isSelected ? RideChromeTokens.go : .white.opacity(0.25))
         }
         .padding(.vertical, 10)
         .padding(.horizontal, 12)
         .background(
            .white.opacity(isSelected ? 0.09 : 0.04),
            in: .rect(cornerRadius: 12)
         )
         .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
               .strokeBorder(
                  isSelected ? RideChromeTokens.go.opacity(0.5) : .white.opacity(0.06),
                  lineWidth: 1
               )
         }
         .contentShape(.rect(cornerRadius: 12))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(system.title) units")
      .accessibilityValue(system.exampleText)
      .accessibilityAddTraits(isSelected ? .isSelected : [])
      .accessibilityIdentifier("setup.units.\(system.rawValue)")
   }

   // MARK: - Radar

   private var radarCard: some View {
      Button {
         finish()
         onShowRadar()
      } label: {
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

   // MARK: - Pieces

   private func cardHeader(_ title: String) -> some View {
      Text(title)
         .font(.caption2.weight(.bold))
         .kerning(1.2)
         .foregroundStyle(.white.opacity(0.45))
   }

   private var footnote: some View {
      Text("You can come back any time from the gear on the dashboard.")
         .font(.caption2)
         .foregroundStyle(.white.opacity(0.35))
         .multilineTextAlignment(.center)
         .padding(.horizontal, 8)
         .padding(.top, 4)
   }

   private func finish() {
      unitsSettings.hasCompletedSetup = true
      dismiss()
   }
}

#Preview {
   RideSetupView(unitsSettings: RideUnitsSettings(), onShowRadar: {})
}
