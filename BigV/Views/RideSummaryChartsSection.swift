//
//  RideSummaryChartsSection.swift
//  BigV
//

import SwiftUI

/// Post-ride telemetry cards — same reports as ride detail, under the summary map.
struct RideSummaryChartsSection: View {

   let rideDetailViewModel: RideDetailViewModel

   var body: some View {
      if rideDetailViewModel.isLoaded {
         VStack(spacing: 12) {
            if let laps = rideDetailViewModel.laps {
               RideLapsCard(report: laps)
            }

            if let elevation = rideDetailViewModel.elevation {
               RideElevationCard(report: elevation)
            }

            if let speed = rideDetailViewModel.speed {
               RideSpeedCard(report: speed)
            }

            if let heartRate = rideDetailViewModel.heartRate {
               RideHeartRateCard(report: heartRate)
            }

            if let radar = rideDetailViewModel.radar {
               RideRadarTrafficCard(report: radar)
            }
         }
      }
   }
}
