//
//  RideDashboardInstrumentHero.swift
//  BigV
//

import SwiftUI

/// The speed hero — always visible; live metric charts sit beneath it.
struct RideDashboardInstrumentHero: View {

   let rideViewModel: RideViewModel
   let isExpanded: Bool

   var body: some View {
      RideSpeedHeroView(
         value: rideViewModel.speed,
         unit: rideViewModel.speedUnit,
         course: rideViewModel.course,
         heading: rideViewModel.heading,
         headingDegrees: rideViewModel.headingDegrees,
         isDimmed: isDimmed,
         isExpanded: isExpanded
      )
      .onChange(of: rideViewModel.phase) { _, _ in
         rideViewModel.syncLiveChartLifecycle()
      }
   }

   private var isDimmed: Bool {
      rideViewModel.isPaused
   }
}
