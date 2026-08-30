//
//  RideDetailLineChart.swift
//  BigV
//

import Charts
import SwiftUI

/// The detail screen's shared telemetry chart: one tinted series on a dark
/// instrument face, with an optional area fill, an average reference line,
/// flagged peaks and a touch scrub that reads out the exact value.
///
/// Elevation, speed and heart rate all wear this so the cards feel like one
/// machine rather than three libraries.
struct RideDetailLineChart: View {

   let points: [RideChartPoint]
   let tint: Color

   var fillsArea = false
   var yDomain: ClosedRange<Double>?
   var averageY: Double?
   var peakPoint: RideChartPoint?
   var lowPoint: RideChartPoint?
   var height: CGFloat = 150

   /// Readouts for the scrub callout, e.g. "1.2 MI" and "213 FT".
   let xCalloutLabel: (Double) -> String
   let yCalloutLabel: (Double) -> String

   @State private var selectedX: Double?

   var body: some View {
      Chart {
         series
         averageRule
         extremeFlags
         scrubMarks
      }
      .chartYScale(domain: resolvedYDomain)
      .chartXSelection(value: $selectedX)
      .chartXAxis { compactAxis }
      .chartYAxis { compactAxis }
      .frame(height: height)
      .accessibilityLabel("Telemetry chart")
   }

   // MARK: - Series

   @ChartContentBuilder
   private var series: some ChartContent {
      ForEach(Array(points.enumerated()), id: \.offset) { _, point in
         if fillsArea {
            AreaMark(
               x: .value("Position", point.x),
               yStart: .value("Base", resolvedYDomain.lowerBound),
               yEnd: .value("Value", point.y)
            )
            .foregroundStyle(areaGradient)
            .interpolationMethod(.monotone)
         }

         LineMark(
            x: .value("Position", point.x),
            y: .value("Value", point.y)
         )
         .foregroundStyle(tint)
         .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
         .interpolationMethod(.monotone)
      }
   }

   // MARK: - Average

   @ChartContentBuilder
   private var averageRule: some ChartContent {
      if let averageY {
         RuleMark(y: .value("Average", averageY))
            .foregroundStyle(.white.opacity(0.3))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .annotation(position: .top, alignment: .trailing, spacing: 2) {
               Text("AVG")
                  .font(.system(size: 8, weight: .bold))
                  .kerning(0.8)
                  .foregroundStyle(.white.opacity(0.4))
            }
      }
   }

   // MARK: - Extremes

   /// The ride's high and low, flagged right on the line — hidden while the
   /// rider is scrubbing so the callout owns the stage.
   @ChartContentBuilder
   private var extremeFlags: some ChartContent {
      if selectedX == nil {
         if let peakPoint {
            extremeFlag(at: peakPoint, position: .top)
         }
         if let lowPoint {
            extremeFlag(at: lowPoint, position: .bottom)
         }
      }
   }

   private func extremeFlag(
      at point: RideChartPoint,
      position: AnnotationPosition
   ) -> some ChartContent {
      PointMark(
         x: .value("Position", point.x),
         y: .value("Value", point.y)
      )
      .symbolSize(36)
      .foregroundStyle(tint)
      .annotation(
         position: position,
         spacing: 3,
         overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
      ) {
         Text(yCalloutLabel(point.y))
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.black.opacity(0.55), in: .capsule)
      }
   }

   // MARK: - Scrubbing

   @ChartContentBuilder
   private var scrubMarks: some ChartContent {
      if let selected = selectedPoint {
         RuleMark(x: .value("Selected", selected.x))
            .foregroundStyle(.white.opacity(0.22))
            .lineStyle(StrokeStyle(lineWidth: 1))

         PointMark(
            x: .value("Selected", selected.x),
            y: .value("Value", selected.y)
         )
         .symbolSize(70)
         .foregroundStyle(tint)
         .annotation(
            position: .top,
            spacing: 6,
            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
         ) {
            calloutPlate(for: selected)
         }
      }
   }

   private func calloutPlate(for point: RideChartPoint) -> some View {
      VStack(spacing: 0) {
         Text(yCalloutLabel(point.y))
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)

         Text(xCalloutLabel(point.x))
            .font(.system(size: 9, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.55))
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(.black.opacity(0.75), in: .rect(cornerRadius: 8, style: .continuous))
      .overlay {
         RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(tint.opacity(0.5), lineWidth: 1)
      }
   }

   /// Nearest plotted point to the touch. The series is a couple hundred
   /// points at most, so a linear scan costs nothing.
   private var selectedPoint: RideChartPoint? {
      guard let selectedX else { return nil }
      return points.min { abs($0.x - selectedX) < abs($1.x - selectedX) }
   }

   // MARK: - Styling

   private var resolvedYDomain: ClosedRange<Double> {
      if let yDomain { return yDomain }

      let values = points.map(\.y)
      guard let minY = values.min(), let maxY = values.max() else { return 0...1 }

      let padding = max((maxY - minY) * 0.15, 1)
      return (minY - padding)...(maxY + padding)
   }

   private var areaGradient: LinearGradient {
      LinearGradient(
         colors: [tint.opacity(0.32), tint.opacity(0.02)],
         startPoint: .top,
         endPoint: .bottom
      )
   }

   private var compactAxis: some AxisContent {
      AxisMarks(values: .automatic(desiredCount: 4)) { value in
         AxisGridLine()
            .foregroundStyle(.white.opacity(0.06))

         AxisValueLabel {
            if let number = value.as(Double.self) {
               Text(number.formatted(.number.precision(.fractionLength(0...1))))
                  .font(.system(size: 9, weight: .medium))
                  .monospacedDigit()
                  .foregroundStyle(.white.opacity(0.35))
            }
         }
      }
   }
}

#Preview {
   ZStack {
      Color.black
      RideDetailLineChart(
         points: (0..<60).map { index in
            RideChartPoint(
               x: Double(index) / 20,
               y: 100 + 30 * sin(Double(index) / 6) + Double(index) / 3
            )
         },
         tint: RideDashboardTheme.ice,
         fillsArea: true,
         xCalloutLabel: { "\($0.formatted(.number.precision(.fractionLength(1)))) MI" },
         yCalloutLabel: { "\($0.formatted(.number.precision(.fractionLength(0)))) FT" }
      )
      .padding()
   }
   .preferredColorScheme(.dark)
}
