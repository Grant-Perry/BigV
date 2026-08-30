//
//  RideLiveRadarTimelineStrip.swift
//  BigV
//

import SwiftUI

/// Live traffic timeline under the speed hero while recording.
struct RideLiveRadarTimelineStrip: View {

   let report: RideRadarReport?
   let onDismiss: () -> Void

   var body: some View {
      VStack(alignment: .leading, spacing: 8) {
         headerRow

         if let report, !report.points.isEmpty {
            RideRadarPassTimelineChart(report: report, height: 76)

            Text("\(report.vehicleCountText) vehicles · closest \(report.closestPassText)")
               .font(.caption2.weight(.medium))
               .foregroundStyle(.white.opacity(0.45))
         } else {
            Text("No completed passes yet — the timeline fills as vehicles pass.")
               .font(.caption.weight(.medium))
               .foregroundStyle(.white.opacity(0.4))
               .frame(maxWidth: .infinity, minHeight: 76, alignment: .center)
         }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .rideGlassCard(density: .hud)
   }

   private var headerRow: some View {
      HStack(spacing: 6) {
         Image(systemName: "car.rear.waves.up")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(RideDashboardTheme.amber)

         Text("TRAFFIC TIMELINE")
            .font(.caption2.weight(.bold))
            .kerning(0.8)
            .foregroundStyle(.white.opacity(0.55))

         Spacer()

         Button(action: onDismiss) {
            Image(systemName: "xmark")
               .font(.caption2.weight(.bold))
               .foregroundStyle(.white.opacity(0.45))
               .frame(width: 24, height: 24)
               .contentShape(.rect)
         }
         .buttonStyle(.plain)
         .accessibilityLabel("Close traffic timeline")
      }
   }
}
