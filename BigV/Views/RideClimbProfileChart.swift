//
//  RideClimbProfileChart.swift
//  BigV
//

import Charts
import SwiftUI

/// The climb page's hero: the road ahead as a grade-coloured area — easy green
/// through amber into red where it bites — with a crest line on top and the
/// rider as a glowing playhead.
///
/// Pure rendering: every coordinate arrives pre-converted in the series, so
/// this view's only opinion is what each grade looks like.
struct RideClimbProfileChart: View {

   let series: RideClimbProfileSeries
   let climbSpans: [RideClimbChartSpan]
   let height: CGFloat

   var body: some View {
      Chart {
         spanMarks
         areaMarks
         crestLine
         playheadMarks
      }
      .chartYScale(domain: series.altitudeRange)
      .chartXScale(domain: 0...max(series.xSpan, 0.01))
      .chartXAxis { distanceAxis }
      .chartYAxis { altitudeAxis }
      .frame(height: height)
      .accessibilityLabel("Elevation profile")
   }

   // MARK: - Climb Footprints

   /// Faint pillars under the climbs on the whole-route view, each wearing its
   /// category badge, so the rider reads the day's shape in one glance.
   @ChartContentBuilder
   private var spanMarks: some ChartContent {
      ForEach(climbSpans) { span in
         RectangleMark(
            xStart: .value("Start", span.startX),
            xEnd: .value("End", span.endX),
            yStart: .value("Base", series.altitudeRange.lowerBound),
            yEnd: .value("Top", series.altitudeRange.upperBound)
         )
         .foregroundStyle(RideDashboardTheme.ember.opacity(0.08))
         .annotation(position: .top, spacing: 0) {
            Text(span.label)
               .font(.system(size: 8, weight: .bold))
               .kerning(0.6)
               .foregroundStyle(RideDashboardTheme.ember.opacity(0.75))
         }
      }
   }

   // MARK: - Profile

   @ChartContentBuilder
   private var areaMarks: some ChartContent {
      ForEach(series.points) { point in
         AreaMark(
            x: .value("Distance", point.x),
            yStart: .value("Base", series.altitudeRange.lowerBound),
            yEnd: .value("Altitude", point.altitude)
         )
         .foregroundStyle(gradeGradient(opacity: 0.5))
         .interpolationMethod(.monotone)
      }
   }

   @ChartContentBuilder
   private var crestLine: some ChartContent {
      ForEach(series.points) { point in
         LineMark(
            x: .value("Distance", point.x),
            y: .value("Altitude", point.altitude)
         )
         .foregroundStyle(gradeGradient(opacity: 1))
         .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
         .interpolationMethod(.monotone)
      }
   }

   // MARK: - Playhead

   @ChartContentBuilder
   private var playheadMarks: some ChartContent {
      if let playhead = series.playhead {
         RuleMark(x: .value("You", playhead.x))
            .foregroundStyle(RideDashboardTheme.ice.opacity(0.35))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))

         PointMark(
            x: .value("You", playhead.x),
            y: .value("Altitude", playhead.altitude)
         )
         .symbolSize(120)
         .foregroundStyle(RideDashboardTheme.ice)
         .annotation(position: .top, spacing: 4) {
            Text("YOU")
               .font(.system(size: 8, weight: .bold, design: .rounded))
               .kerning(1)
               .foregroundStyle(RideDashboardTheme.ice.opacity(0.9))
               .padding(.horizontal, 5)
               .padding(.vertical, 2)
               .background(.black.opacity(0.55), in: .capsule)
         }
      }
   }

   // MARK: - Grade Colour

   /// One horizontal gradient across the plot, coloured by each point's grade,
   /// so the fill and the crest line agree about where the road hurts.
   private func gradeGradient(opacity: Double) -> LinearGradient {
      let count = series.points.count
      let span = max(series.xSpan, 0.001)

      // Gradients get expensive past a hundred-odd stops; the eye cannot tell.
      let stride = max(1, count / 100)
      var stops: [Gradient.Stop] = []
      stops.reserveCapacity(count / stride + 1)

      for index in Swift.stride(from: 0, to: count, by: stride) {
         let point = series.points[index]
         stops.append(
            Gradient.Stop(
               color: Self.color(forGrade: point.grade).opacity(opacity),
               location: min(max(point.x / span, 0), 1)
            )
         )
      }

      return LinearGradient(
         gradient: Gradient(stops: stops),
         startPoint: .leading,
         endPoint: .trailing
      )
   }

   /// The ramp riders already know: green is spinning, amber is working, red
   /// is out of the saddle. Descents cool to ice.
   static func color(forGrade grade: Double) -> Color {
      switch grade {
         case ..<(-2):
            RideDashboardTheme.ice

         case ..<3:
            RideDashboardTheme.go

         case ..<6:
            RideDashboardTheme.go.mix(
               with: RideDashboardTheme.amber,
               by: (grade - 3) / 3
            )

         case ..<10:
            RideDashboardTheme.amber.mix(
               with: RideDashboardTheme.halt,
               by: (grade - 6) / 4
            )

         default:
            RideDashboardTheme.halt
      }
   }

   // MARK: - Axes

   private var distanceAxis: some AxisContent {
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

   private var altitudeAxis: some AxisContent {
      AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
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

#Preview {
   ZStack {
      Color.black

      RideClimbProfileChart(
         series: RideClimbProfileSeriesBuilder.series(
            profile: (0..<120).map { index in
               RouteElevationSample(
                  distanceAlongRoute: Double(index) * 75,
                  altitude: 300 + Double(index) * 4 + 25 * sin(Double(index) / 8)
               )
            },
            start: 0,
            end: 9_000,
            playheadDistance: 3_200,
            playheadAltitude: 480,
            system: .imperial
         )!,
         climbSpans: [],
         height: 240
      )
      .padding()
   }
   .preferredColorScheme(.dark)
}
