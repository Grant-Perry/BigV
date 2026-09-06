//
//  RideSummaryView.swift
//  BigV
//

import SwiftUI

/// Post-ride totals, shown once the ride is finished and safely on disk.
struct RideSummaryView: View {

   let rideViewModel: RideViewModel
   let rideRouteViewModel: RideRouteViewModel
   let rideDetailViewModel: RideDetailViewModel

   var body: some View {
      VStack(spacing: 14) {
         header

         ScrollView {
            VStack(spacing: 12) {
               RideRouteMapView(
                  route: rideRouteViewModel.route,
                  isLoaded: rideRouteViewModel.isLoaded,
                  height: 200,
                  radarPasses: rideRouteViewModel.radarPasses
               )

               RideTotalsGridView(totals: rideViewModel.totals, identifierPrefix: "summary.tile")

               RideSummaryChartsSection(rideDetailViewModel: rideDetailViewModel)
            }
            .padding(.bottom, 4)
         }
         .scrollIndicators(.hidden)

         statusLines

         controls
      }
      .padding(.horizontal, 16)
      .padding(.top, 10)
      .padding(.bottom, 18)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .task(id: rideViewModel.finishedRideID) {
         rideRouteViewModel.load(rideViewModel.finishedRideID)
         await rideDetailViewModel.load(rideViewModel.finishedRideID)
      }
   }

   // MARK: - Header

   private var header: some View {
         Text("RIDE COMPLETE")
         .font(.caption.weight(.bold))
         .kerning(1.6)
         .foregroundStyle(RideDashboardTheme.ember)
         .frame(maxWidth: .infinity, alignment: .leading)
   }

   // MARK: - Status

   private var statusLines: some View {
      VStack(alignment: .leading, spacing: 4) {
         if let healthKitStatusText = rideViewModel.healthKitStatusText {
            Label(healthKitStatusText, systemImage: rideViewModel.didSaveToHealthKit ? .savedIcon : .pendingIcon)
               .font(.caption.weight(.medium))
               .foregroundStyle(rideViewModel.didSaveToHealthKit ? .green : RideDashboardTheme.ink(0.5))
         }

         if let storageWarning = rideViewModel.storageWarning {
            Label(storageWarning, systemImage: .warningIcon)
               .font(.caption.weight(.medium))
               .foregroundStyle(.orange)
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
   }

   // MARK: - Controls

   private var controls: some View {
      HStack(spacing: 10) {
         control("DONE", tint: RideDashboardTheme.ink, isPrimary: false, action: rideViewModel.reset)
         control("NEW RIDE", tint: RideDashboardTheme.go, isPrimary: true, action: rideViewModel.startNewRide)
      }
   }

   @ViewBuilder
   private func control(
      _ title: String,
      tint: Color,
      isPrimary: Bool,
      action: @escaping () -> Void
   ) -> some View {
      let button = Button(action: action) {
         Text(title)
            .font(.subheadline.weight(.bold))
            .kerning(1)
            .frame(maxWidth: .infinity)
      }
      .controlSize(.extraLarge)
      .tint(tint)

      if isPrimary {
         button.buttonStyle(.borderedProminent)
      } else {
         button.buttonStyle(.bordered)
      }
   }
}

// MARK: - Icons

private extension String {
   static let savedIcon = "checkmark.circle.fill"
   static let pendingIcon = "heart.text.square"
   static let warningIcon = "exclamationmark.triangle.fill"
}

#Preview {
   RideSummaryView(
      rideViewModel: RideViewModel(),
      rideRouteViewModel: RideRouteViewModel(),
      rideDetailViewModel: RideDetailViewModel()
   )
   .preferredColorScheme(.dark)
}
