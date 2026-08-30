//
//  RideDashboardLiveMetricSection.swift
//  BigV
//

import SwiftUI

/// Live charts under the speed hero — metrics and radar timeline.
struct RideDashboardLiveMetricSection: View {

   let rideViewModel: RideViewModel

   var body: some View {
      VStack(spacing: 8) {
         if let metric = rideViewModel.selectedMetric {
            metricSection(metric)
               .transition(.opacity.combined(with: .move(edge: .top)))
         }

         if rideViewModel.isLiveRadarTimelineVisible {
            RideLiveRadarTimelineStrip(
               report: rideViewModel.liveRadarReport,
               onDismiss: { rideViewModel.clearLiveRadarTimeline() }
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
         }
      }
      .animation(.easeInOut(duration: 0.25), value: rideViewModel.selectedMetric)
      .animation(.easeInOut(duration: 0.25), value: rideViewModel.isLiveRadarTimelineVisible)
   }

   @ViewBuilder
   private func metricSection(_ metric: RideLiveMetric) -> some View {
      VStack(spacing: 8) {
         if metric == .heartRate {
            RideLiveHeartRateReadout(
               value: rideViewModel.heartRate ?? RideFormatters.placeholder,
               unit: rideViewModel.heartRateUnit,
               beatsPerMinute: rideViewModel.heartRateBeatsPerMinute,
               isDimmed: !rideViewModel.hasGPSFix || rideViewModel.isPaused
            )
         }

         RideLiveMetricChartStrip(
            metric: metric,
            tint: rideViewModel.liveMetricTint(for: metric),
            showsHeader: metric != .heartRate,
            heartRateReport: rideViewModel.liveHeartRateReport,
            elevationReport: rideViewModel.liveElevationReport,
            speedReport: rideViewModel.liveSpeedReport,
            onDismiss: { rideViewModel.clearSelectedMetric() }
         )
      }
   }
}
