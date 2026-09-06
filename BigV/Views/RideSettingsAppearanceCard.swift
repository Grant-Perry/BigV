//
//  RideSettingsAppearanceCard.swift
//  BigV
//

import SwiftUI

/// The APPEARANCE section: day, night, or the phone's call.
///
/// One control, so it spans the card instead of hiding behind a label that
/// would only repeat the header. The footnote describes the mode the rider has
/// actually chosen — the card teaches on selection rather than listing three
/// explanations nobody reads twice.
struct RideSettingsAppearanceCard: View {

   @Bindable var appearanceSettings: RideAppearanceSettings

   var body: some View {
      RideSettingsCard(title: "APPEARANCE", footnote: footnote) {
         RideSettingsSegmentedControl(
            selection: mode,
            segments: RideAppearanceMode.allCases.map { mode in
               RideSettingsSegment(
                  value: mode,
                  title: mode.shortTitle,
                  symbolName: mode.symbolName,
                  accessibilityLabel: mode.title,
                  identifier: "setup.appearance.\(mode.rawValue)"
               )
            }
         )
      }
   }

   /// Written through with an animation so the whole app cross-fades to the
   /// other palette instead of cutting to it.
   private var mode: Binding<RideAppearanceMode> {
      Binding {
         appearanceSettings.mode
      } set: { newMode in
         withAnimation(.easeInOut(duration: 0.25)) {
            appearanceSettings.mode = newMode
         }
      }
   }

   private var footnote: String {
      "\(appearanceSettings.mode.detail). The sun-and-moon chip on the speedometer flips Day and Night without coming back here."
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()

      RideSettingsAppearanceCard(appearanceSettings: RideAppearanceSettings())
         .padding(16)
   }
   .preferredColorScheme(.dark)
}
