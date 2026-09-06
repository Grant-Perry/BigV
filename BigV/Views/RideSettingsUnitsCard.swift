//
//  RideSettingsUnitsCard.swift
//  BigV
//

import SwiftUI

/// The UNITS section: what every figure in the app reads in.
///
/// Measurement and temperature share a card but never a control — riders
/// routinely want miles with a Celsius sky, or the reverse. The footnote spells
/// out what the pair currently produces rather than describing the options, so
/// it earns its two lines and answers the only real question: what will I see?
struct RideSettingsUnitsCard: View {

   @Bindable var unitsSettings: RideUnitsSettings

   var body: some View {
      RideSettingsCard(title: "UNITS", footnote: footnote) {
         RideSettingsSegmentedRow(
            title: "Measurement",
            selection: $unitsSettings.system,
            segments: RideUnitSystem.allCases.map { system in
               RideSettingsSegment(
                  value: system,
                  title: system.title,
                  identifier: "setup.units.\(system.rawValue)"
               )
            }
         )

         RideSettingsDivider()

         RideSettingsSegmentedRow(
            title: "Temperature",
            selection: $unitsSettings.temperatureUnit,
            segments: RideTemperatureUnit.allCases.map { unit in
               RideSettingsSegment(
                  value: unit,
                  title: unit.title,
                  identifier: "setup.temperature.\(unit.rawValue)"
               )
            }
         )
      }
   }

   private var footnote: String {
      "\(unitsSettings.system.exampleText) · \(unitsSettings.temperatureUnit.exampleText) — speed, distance, elevation, radar ranges, history and your Watch."
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()

      RideSettingsUnitsCard(unitsSettings: RideUnitsSettings())
         .padding(16)
   }
   .preferredColorScheme(.dark)
}
