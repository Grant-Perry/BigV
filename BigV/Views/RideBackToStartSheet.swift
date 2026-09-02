//
//  RideBackToStartSheet.swift
//  BigV
//

import SwiftUI

/// Garmin's two ways home, as a confirmation sheet.
///
/// A sheet rather than a third control-bar button: going home is a decision
/// made once a ride, not chrome the rider reaches for at speed. Retrace leads
/// because it always works — the breadcrumb is already on the phone — while
/// most-direct depends on Apple having cycling coverage here.
struct RideBackToStartSheet: View {

   let backToStartModel: RideBackToStartModel

   var body: some View {
      VStack(spacing: 14) {
         header

         optionButton(
            title: "Along Same Route",
            detail: "Retrace the ride you just recorded, turn for turn",
            icon: "arrow.uturn.backward",
            identifier: "backToStart.option.retrace",
            action: backToStartModel.retraceRoute
         )

         optionButton(
            title: "Most Direct",
            detail: "A fresh cycling route straight back to your start",
            icon: "point.topleft.down.to.point.bottomright.curvepath",
            identifier: "backToStart.option.direct",
            action: backToStartModel.planMostDirect
         )

         if backToStartModel.isPlanning {
            ProgressView("Finding the way back…")
               .tint(RideDashboardTheme.ink(0.7))
               .font(.footnote)
               .foregroundStyle(RideDashboardTheme.ink(0.6))
         }

         if let failureMessage = backToStartModel.failureMessage {
            Text(failureMessage)
               .font(.footnote)
               .foregroundStyle(RideDashboardTheme.halt)
               .multilineTextAlignment(.center)
         }
      }
      .padding(20)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background {
         RideAtmosphereBackground()
            .ignoresSafeArea()
      }
      .presentationDetents([.medium])
      .presentationDragIndicator(.visible)
   }

   // MARK: - Header

   private var header: some View {
      VStack(spacing: 6) {
         Image(systemName: "house.fill")
            .font(.title3.weight(.semibold))
            .foregroundStyle(RideDashboardTheme.ice)

         Text("BACK TO START")
            .font(.caption.weight(.bold))
            .kerning(1.6)
            .foregroundStyle(RideDashboardTheme.ink(0.7))

         Text("Guidance takes over as soon as you choose.")
            .font(.caption)
            .foregroundStyle(RideDashboardTheme.ink(0.45))
      }
      .padding(.top, 8)
   }

   // MARK: - Options

   private func optionButton(
      title: String,
      detail: String,
      icon: String,
      identifier: String,
      action: @escaping () -> Void
   ) -> some View {
      Button(action: action) {
         HStack(spacing: 12) {
            Image(systemName: icon)
               .font(.title3.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ice)
               .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
               Text(title)
                  .font(.subheadline.weight(.bold))
                  .foregroundStyle(RideDashboardTheme.ink)

               Text(detail)
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
      .rideGlassCard(density: .standard)
      .disabled(backToStartModel.isPlanning)
      .accessibilityIdentifier(identifier)
   }
}

#Preview {
   RideBackToStartSheet(backToStartModel: RideBackToStartModel())
      .preferredColorScheme(.dark)
}
