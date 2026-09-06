//
//  RideSettingsRows.swift
//  BigV
//

import SwiftUI

/// A row that leads somewhere else: title, one-line note, chevron — and a glyph
/// only when it earns one.
///
/// Inside a card of mixed rows the glyph is left off. A toggle and a segmented
/// control cannot afford a 26-point rail without crowding their controls, and a
/// single row indented past its neighbours reads as a mistake. Standalone action
/// cards, which have no neighbours to line up with, keep it.
struct RideSettingsNavRow: View {

   var symbolName: String?
   let title: String
   let detail: String
   var tint: Color = RideDashboardTheme.ice
   var showsChevron = true
   let identifier: String
   let action: () -> Void

   var body: some View {
      Button(action: action) {
         HStack(spacing: 12) {
            if let symbolName {
               Image(systemName: symbolName)
                  .font(.title3.weight(.semibold))
                  .foregroundStyle(tint)
                  .frame(width: 26)
            }

            VStack(alignment: .leading, spacing: 2) {
               Text(title)
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(RideDashboardTheme.ink)

               Text(detail)
                  .font(.caption)
                  .foregroundStyle(RideDashboardTheme.ink(0.55))
                  .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if showsChevron {
               Image(systemName: "chevron.right")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(RideDashboardTheme.ink(0.3))
            }
         }
         .frame(maxWidth: .infinity, alignment: .leading)
         .contentShape(.rect)
      }
      .buttonStyle(RideSettingsRowButtonStyle())
      .accessibilityIdentifier(identifier)
   }
}

// MARK: - Toggle

/// A row that flips something: title, one-line note, switch.
struct RideSettingsToggleRow: View {

   let title: String
   let detail: String
   @Binding var isOn: Bool
   var tint: Color = RideDashboardTheme.ember
   let identifier: String

   var body: some View {
      Toggle(isOn: $isOn) {
         VStack(alignment: .leading, spacing: 2) {
            Text(title)
               .font(.subheadline.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ink)

            Text(detail)
               .font(.caption)
               .foregroundStyle(RideDashboardTheme.ink(0.55))
               .fixedSize(horizontal: false, vertical: true)
         }
      }
      .tint(tint)
      .sensoryFeedback(.selection, trigger: isOn)
      .accessibilityIdentifier(identifier)
   }
}

// MARK: - Press Feedback

/// Rows inside a card carry no resting fill, so a tap needs its own answer.
///
/// The highlight is inset past the label to the card's own padding, which makes
/// it read as the row lighting up rather than the text growing a box.
private struct RideSettingsRowButtonStyle: ButtonStyle {

   func makeBody(configuration: Configuration) -> some View {
      configuration.label
         .background {
            RoundedRectangle(cornerRadius: RideSettingsMetrics.rowCornerRadius, style: .continuous)
               .fill(RideDashboardTheme.ink(configuration.isPressed ? 0.08 : 0))
               .padding(.horizontal, -8)
               .padding(.vertical, -7)
         }
         .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
   }
}

#Preview {
   @Previewable @State var isOn = true

   ZStack {
      RideAtmosphereBackground()

      RideSettingsCard(title: "RIDING", footnote: "A lap every 5 miles. The LAP button still works.") {
         RideSettingsNavRow(
            symbolName: "car.rear.waves.up",
            title: "Rear Radar",
            detail: "Varia™ rear radar compatible",
            identifier: "preview.radar"
         ) {}

         RideSettingsDivider()

         RideSettingsToggleRow(
            title: "Climb Page Auto-Switch",
            detail: "Jump to the climb page when a categorized climb starts",
            isOn: $isOn,
            identifier: "preview.climb"
         )
      }
      .padding(16)
   }
   .preferredColorScheme(.dark)
}
