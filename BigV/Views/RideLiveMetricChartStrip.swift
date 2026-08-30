//
//  RideLiveMetricChartStrip.swift
//  BigV
//

import SwiftUI

/// Compact live chart that sits under the speed hero — speed never moves.
struct RideLiveMetricChartStrip: View {

   let metric: RideLiveMetric
   let tint: Color
   var showsHeader: Bool = true

   let heartRateReport: RideHeartRateReport?
   let elevationReport: RideElevationReport?
   let speedReport: RideSpeedReport?

   let onDismiss: () -> Void

   private let chartHeight: CGFloat = 76

   var body: some View {
      VStack(alignment: .leading, spacing: 8) {
         if showsHeader {
            headerRow
         }
         chartSection
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .rideGlassCard(density: .hud)
      .accessibilityElement(children: .contain)
      .accessibilityLabel("\(metric.title) chart")
   }

   // MARK: - Header

   private var headerRow: some View {
      HStack(spacing: 6) {
         Image(systemName: metric.iconName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)

         Text(metric.title)
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
         .accessibilityLabel("Close chart")
         .accessibilityIdentifier("ride.liveMetric.dismiss")
      }
   }

   /// Shown when the chart strip has no title row (heart rate uses the readout above).
   private var dismissOnlyHeader: some View {
      HStack {
         Spacer()
         Button(action: onDismiss) {
            Image(systemName: "xmark")
               .font(.caption2.weight(.bold))
               .foregroundStyle(.white.opacity(0.45))
               .frame(width: 24, height: 24)
               .contentShape(.rect)
         }
         .buttonStyle(.plain)
         .accessibilityLabel("Close chart")
         .accessibilityIdentifier("ride.liveMetric.dismiss")
      }
   }

   @ViewBuilder
   private var chartSection: some View {
      if !showsHeader {
         VStack(alignment: .leading, spacing: 6) {
            dismissOnlyHeader
            chartContent
         }
      } else {
         chartContent
      }
   }

   @ViewBuilder
   private var chartContent: some View {
      switch metric {
         case .heartRate:
            if let heartRateReport, !heartRateReport.points.isEmpty {
               RideDetailLineChart(
                  points: heartRateReport.points,
                  tint: tint,
                  peakPoint: heartRateReport.maximumPoint,
                  lowPoint: heartRateReport.minimumPoint,
                  height: chartHeight,
                  xCalloutLabel: { elapsedMinutes($0) },
                  yCalloutLabel: { "\(whole($0)) BPM" }
               )
            } else {
               waitingLabel
            }

         case .elevation:
            if let elevationReport {
               RideDetailLineChart(
                  points: elevationReport.points,
                  tint: tint,
                  fillsArea: true,
                  yDomain: elevationReport.yDomain,
                  height: chartHeight,
                  xCalloutLabel: { "\(compact($0)) \(elevationReport.distanceUnit)" },
                  yCalloutLabel: { "\(whole($0)) \(elevationReport.elevationUnit)" }
               )
            } else {
               waitingLabel
            }

         case .speed:
            if let speedReport {
               RideDetailLineChart(
                  points: speedReport.points,
                  tint: tint,
                  fillsArea: true,
                  averageY: speedReport.averageValue,
                  height: chartHeight,
                  xCalloutLabel: { "\(compact($0)) \(speedReport.distanceUnit)" },
                  yCalloutLabel: { "\(compact($0)) \(speedReport.speedUnit)" }
               )
            } else {
               waitingLabel
            }
      }
   }

   private var waitingLabel: some View {
      Text(metric.waitingMessage)
         .font(.caption.weight(.medium))
         .foregroundStyle(.white.opacity(0.4))
         .frame(maxWidth: .infinity, minHeight: chartHeight, alignment: .center)
   }

   // MARK: - Labels

   private func whole(_ value: Double) -> String {
      value.formatted(.number.precision(.fractionLength(0)))
   }

   private func compact(_ value: Double) -> String {
      value.formatted(.number.precision(.fractionLength(0...1)))
   }

   private func elapsedMinutes(_ minutes: Double) -> String {
      "at \(minutes.formatted(.number.precision(.fractionLength(0)))) min"
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      RideLiveMetricChartStrip(
         metric: .heartRate,
         tint: RideDashboardTheme.pulse,
         heartRateReport: RideHeartRateReport(
            points: (0..<40).map { RideChartPoint(x: Double($0), y: 120 + Double($0 % 8) * 3) },
            averageText: "138",
            maximumText: "156",
            minimumText: "118",
            maximumPoint: RideChartPoint(x: 30, y: 156),
            minimumPoint: RideChartPoint(x: 4, y: 118),
            caloriesText: nil,
            isFromAppleHealth: false
         ),
         elevationReport: nil,
         speedReport: nil,
         onDismiss: {}
      )
      .padding()
   }
   .preferredColorScheme(.dark)
}
