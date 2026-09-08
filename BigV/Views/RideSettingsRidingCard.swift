//
//  RideSettingsRidingCard.swift
//  BigV
//

import SwiftUI

/// The RIDING section: radar, climb auto-switch, auto-lap, and the way back
/// to the stock card layout.
///
/// Grouped because all of these are about what the cockpit does on its own
/// while the rider keeps their hands on the bars, which is also why radar sits
/// here as a row rather than as a card of its own further down the page.
struct RideSettingsRidingCard: View {

   @Bindable var unitsSettings: RideUnitsSettings
   @Bindable var climbSettings: RideClimbSettings
   @Bindable var lapSettings: RideLapSettings
   let cockpitLayoutSettings: RideCockpitLayoutSettings
   let onShowRadar: () -> Void

   var body: some View {
      RideSettingsCard(title: "RIDING", footnote: autoLapFootnote) {
         RideSettingsNavRow(
            title: "Rear Radar",
            detail: "Varia™ rear radar compatible",
            identifier: "setup.button.radar",
            action: onShowRadar
         )

         RideSettingsDivider()

         RideSettingsToggleRow(
            title: "Climb Page Auto-Switch",
            detail: "Jump to the climb page when a categorized climb starts",
            isOn: $climbSettings.autoSwitchEnabled,
            identifier: "settings.toggle.climbAutoSwitch"
         )

         RideSettingsDivider()

         RideSettingsSegmentedRow(
            title: "Auto-Lap",
            selection: $lapSettings.autoLapUnits,
            segments: autoLapSegments
         )

         RideSettingsDivider()

         // A layout built by holding cards with a gloved thumb is easy to
         // scramble, so the way back is one row, not a rebuild by hand.
         RideSettingsNavRow(
            title: "Reset Card Layout",
            detail: "Put every dashboard and traffic card back where it started",
            showsChevron: false,
            identifier: "settings.button.resetCardLayout"
         ) {
            cockpitLayoutSettings.reset()
         }
      }
   }

   // MARK: - Auto-Lap

   private var autoLapSegments: [RideSettingsSegment<Double>] {
      RideLapSettings.autoLapChoices.map { choice in
         RideSettingsSegment(
            value: choice,
            title: choice == 0 ? "Off" : Self.value(choice),
            accessibilityLabel: choice == 0
               ? "Auto-lap off"
               : "Every \(Self.value(choice)) \(distanceWord)",
            identifier: "settings.picker.autoLap.\(Int(choice))"
         )
      }
   }

   private var autoLapFootnote: String {
      guard lapSettings.autoLapUnits > 0 else {
         return "Auto-lap is off — the LAP button still cuts a lap whenever you press it."
      }

      return "A lap every \(Self.value(lapSettings.autoLapUnits)) \(distanceWord), hands on the bars. The LAP button still works."
   }

   private var distanceWord: String {
      unitsSettings.system == .imperial ? "miles" : "kilometers"
   }

   private static func value(_ choice: Double) -> String {
      choice.formatted(.number.precision(.fractionLength(0)))
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()

      RideSettingsRidingCard(
         unitsSettings: RideUnitsSettings(),
         climbSettings: RideClimbSettings(),
         lapSettings: RideLapSettings(),
         cockpitLayoutSettings: RideCockpitLayoutSettings(),
         onShowRadar: {}
      )
      .padding(16)
   }
   .preferredColorScheme(.dark)
}
