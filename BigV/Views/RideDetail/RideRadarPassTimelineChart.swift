//
//  RideRadarPassTimelineChart.swift
//  BigV
//

import Charts
import SwiftUI

/// Scatter timeline of vehicle passes — shared by ride detail and the live cockpit.
struct RideRadarPassTimelineChart: View {

   let report: RideRadarReport
   var height: CGFloat = 120

   var body: some View {
      Chart(report.points) { pass in
         PointMark(
            x: .value("Minutes", pass.minutes),
            y: .value("Distance", pass.distance)
         )
         .symbolSize(pass.isHighTier ? 90 : 50)
         .foregroundStyle(
            pass.isHighTier ? RideChromeTokens.halt : RideChromeTokens.amber
         )
         .opacity(0.9)
      }
      .chartXScale(domain: 0...report.durationMinutes)
      .chartYScale(domain: 0...yCeiling)
      .chartXAxis { compactAxis }
      .chartYAxis { compactAxis }
      .frame(height: height)
      .accessibilityLabel("Vehicle pass timeline")
      .accessibilityValue("\(report.vehicleCountText) passes")
   }

   private var yCeiling: Double {
      let farthest = report.points.map(\.distance).max() ?? 1
      return farthest * 1.25
   }

   private var compactAxis: some AxisContent {
      AxisMarks(values: .automatic(desiredCount: 4)) { value in
         AxisGridLine()
            .foregroundStyle(.white.opacity(0.06))

         AxisValueLabel {
            if let number = value.as(Double.self) {
               Text(number.formatted(.number.precision(.fractionLength(0))))
                  .font(.system(size: 9, weight: .medium))
                  .monospacedDigit()
                  .foregroundStyle(.white.opacity(0.35))
            }
         }
      }
   }
}
