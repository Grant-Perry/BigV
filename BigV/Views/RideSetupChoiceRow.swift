//
//  RideSetupChoiceRow.swift
//  BigV
//

import SwiftUI

/// One pickable option in a setup card: title, example, and a filled check.
///
/// Extracted because setup now carries two of these lists — measurement system
/// and temperature scale — and a rider must not be able to tell which card they
/// are looking at from the styling alone.
struct RideSetupChoiceRow: View {

   let title: String
   let detail: String
   let isSelected: Bool
   let identifier: String
   let action: () -> Void

   var body: some View {
      Button(action: action) {
         HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
               Text(title)
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(RideDashboardTheme.ink)

               Text(detail)
                  .font(.caption)
                  .foregroundStyle(RideDashboardTheme.ink(0.55))
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
               .font(.title3)
               .foregroundStyle(isSelected ? RideDashboardTheme.go : RideDashboardTheme.ink(0.25))
         }
         .padding(.vertical, 10)
         .padding(.horizontal, 12)
         .background(
            RideDashboardTheme.ink(isSelected ? 0.09 : 0.04),
            in: .rect(cornerRadius: 12)
         )
         .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
               .strokeBorder(
                  isSelected ? RideDashboardTheme.go.opacity(0.5) : RideDashboardTheme.ink(0.06),
                  lineWidth: 1
               )
         }
         .contentShape(.rect(cornerRadius: 12))
      }
      .buttonStyle(.plain)
      .accessibilityLabel(title)
      .accessibilityValue(detail)
      .accessibilityAddTraits(isSelected ? .isSelected : [])
      .accessibilityIdentifier(identifier)
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      VStack(spacing: 8) {
         RideSetupChoiceRow(
            title: "Imperial",
            detail: "mph · miles · feet",
            isSelected: true,
            identifier: "setup.units.imperial"
         ) {}

         RideSetupChoiceRow(
            title: "Metric",
            detail: "km/h · kilometers · meters",
            isSelected: false,
            identifier: "setup.units.metric"
         ) {}
      }
      .padding()
   }
}
