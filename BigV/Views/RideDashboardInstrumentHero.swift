//
//  RideDashboardInstrumentHero.swift
//  BigV
//

import SwiftUI

/// The speed hero — always visible; live metric charts sit beneath it.
///
/// Portrait gives the hero AVG and MAX as corner chips. Landscape carries
/// those in its grid, so the hero there is speed and heading alone.
struct RideDashboardInstrumentHero: View {

   let rideViewModel: RideViewModel
   let isExpanded: Bool
   var layout: RideSpeedHeroView.Layout = .portrait

   var body: some View {
      RideSpeedHeroView(
         value: rideViewModel.speed,
         unit: rideViewModel.speedUnit,
         course: rideViewModel.course,
         heading: rideViewModel.heading,
         headingDegrees: rideViewModel.headingDegrees,
         isDimmed: isDimmed,
         isExpanded: isExpanded,
         layout: layout,
         averageValue: layout == .portrait ? rideViewModel.averageSpeed : nil,
         maximumValue: layout == .portrait ? rideViewModel.maximumSpeed : nil,
         isSpeedChartSelected: rideViewModel.selectedMetric == .speed,
         onSelectSpeedChart: { rideViewModel.selectMetric(.speed) }
      )
      .onChange(of: rideViewModel.phase) { _, _ in
         rideViewModel.syncLiveChartLifecycle()
      }
   }

   private var isDimmed: Bool {
      rideViewModel.isPaused
   }
}
