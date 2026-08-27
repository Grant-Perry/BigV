//
//  RideDashboardView.swift
//  BigV
//

import SwiftUI

/// The primary bike-computer screen.
///
/// Deliberately flat and unanimated: high contrast for direct sunlight and no
/// per-frame work competing with GPS and recording.
struct RideDashboardView: View {

   let rideViewModel: RideViewModel
   let routeGuidanceViewModel: RouteGuidanceViewModel
   let onShowHistory: () -> Void

   private let tileColumns = [
      GridItem(.flexible(), spacing: 10),
      GridItem(.flexible(), spacing: 10)
   ]

   var body: some View {
      VStack(spacing: 14) {
         statusRow

         if routeGuidanceViewModel.isActive {
            RouteGuidanceStripView(routeGuidanceViewModel: routeGuidanceViewModel)
         }

         RideSpeedHeroView(
            value: rideViewModel.speed,
            unit: rideViewModel.speedUnit,
            isDimmed: !rideViewModel.hasGPSFix || rideViewModel.isPaused
         )

         metricGrid

         Spacer(minLength: 0)

         RideControlBar(rideViewModel: rideViewModel)
      }
      .padding(.horizontal, 16)
      .padding(.top, 10)
      .padding(.bottom, 18)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.black)
   }

   // MARK: - Status

   private var statusRow: some View {
      HStack(spacing: 10) {
         RideStatusBar(
            statusText: rideViewModel.statusText,
            accuracyText: rideViewModel.accuracyText,
            issueMessage: rideViewModel.issueMessage,
            hasGPSFix: rideViewModel.hasGPSFix
         )

         if rideViewModel.isIdle {
            Button(action: onShowHistory) {
               Image(systemName: .historyIcon)
                  .font(.footnote.weight(.semibold))
                  .foregroundStyle(.white.opacity(0.55))
                  .frame(width: 44, height: 44)
                  .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ride history")
            .accessibilityIdentifier("ride.button.history")
         }
      }
   }

   // MARK: - Metrics

   private var metricGrid: some View {
      LazyVGrid(columns: tileColumns, spacing: 10) {
         RideMetricTile(
            title: "DISTANCE",
            value: rideViewModel.distance,
            unit: rideViewModel.distanceUnit,
            identifier: "ride.tile.distance"
         )

         RideMetricTile(
            title: "RIDE TIME",
            value: rideViewModel.rideTime,
            identifier: "ride.tile.rideTime"
         )

         RideMetricTile(
            title: "ELEV GAIN",
            value: rideViewModel.elevationGain,
            unit: rideViewModel.elevationUnit
         )

         RideMetricTile(
            title: "GRADE",
            value: rideViewModel.grade,
            unit: rideViewModel.gradeUnit
         )

         RideMetricTile(
            title: "AVG SPEED",
            value: rideViewModel.averageSpeed,
            unit: rideViewModel.speedUnit
         )

         RideMetricTile(
            title: "MAX SPEED",
            value: rideViewModel.maximumSpeed,
            unit: rideViewModel.speedUnit
         )

         if routeGuidanceViewModel.isActive {
            RideMetricTile(
               title: "TO GO",
               value: routeGuidanceViewModel.distanceRemaining,
               unit: routeGuidanceViewModel.distanceRemainingUnit,
               identifier: "ride.tile.toGo"
            )

            RideMetricTile(
               title: "ETA",
               value: routeGuidanceViewModel.arrivalTime,
               identifier: "ride.tile.eta"
            )
         }
      }
   }
}

// MARK: - Icons

private extension String {
   static let historyIcon = "clock.arrow.circlepath"
}

#Preview {
   RideDashboardView(
      rideViewModel: RideViewModel(),
      routeGuidanceViewModel: RouteGuidanceViewModel()
   ) {}
      .preferredColorScheme(.dark)
}
