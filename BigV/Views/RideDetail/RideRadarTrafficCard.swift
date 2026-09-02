//
//  RideRadarTrafficCard.swift
//  BigV
//

import Charts
import SwiftUI

/// The traffic report: every vehicle pass on a timeline, closest approach on
/// the vertical, wearing the same amber/red tier palette as the live tape.
///
/// This is data no other bike computer around shows this way — the radar's
/// whole ride, one glance.
struct RideRadarTrafficCard: View {

   let report: RideRadarReport

   var body: some View {
      VStack(alignment: .leading, spacing: 12) {
         RideDetailCardHeader(
            icon: "car.rear.fill",
            tint: RideDashboardTheme.amber,
            title: "TRAFFIC",
            detail: "\(report.vehicleCountText) VEHICLES"
         )

         if !report.points.isEmpty {
            RideRadarPassTimelineChart(report: report)
            legend
         }

         statRow
      }
      .padding(14)
      .rideGlassCard(density: .standard)
   }

   // MARK: - Legend

   private var legend: some View {
      HStack(spacing: 12) {
         legendDot(RideDashboardTheme.amber, label: "Pass")
         legendDot(RideDashboardTheme.halt, label: "Fast approach")

         Spacer()

         Text("MINUTES ACROSS · \(report.radarDistanceUnit) UP")
            .font(.system(size: 8, weight: .semibold))
            .kerning(0.6)
            .foregroundStyle(RideDashboardTheme.ink(0.3))
      }
   }

   private func legendDot(_ color: Color, label: String) -> some View {
      HStack(spacing: 4) {
         Circle()
            .fill(color)
            .frame(width: 6, height: 6)

         Text(label)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(RideDashboardTheme.ink(0.5))
      }
   }

   // MARK: - Stats

   private var statRow: some View {
      HStack(spacing: 8) {
         RideDetailFootnoteStat(
            label: "CLOSEST",
            value: report.closestPassText,
            tint: RideDashboardTheme.amber
         )
         RideDetailFootnoteStat(
            label: "MAX CLOSING",
            value: report.maximumClosingText,
            unit: report.speedUnit
         )

         if let density = report.densityText {
            RideDetailFootnoteStat(label: "DENSITY", value: density)
         }

         if let highCount = report.highTierCountText {
            RideDetailFootnoteStat(
               label: "FAST",
               value: highCount,
               tint: RideDashboardTheme.halt
            )
         }
      }
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground(scene: .summary)
      RideRadarTrafficCard(
         report: RideRadarReport(
            vehicleCountText: "8",
            closestPassText: "5 ft",
            maximumClosingText: "136.2",
            speedUnit: "MPH",
            densityText: "2.7 / mi",
            highTierCountText: "2",
            points: [
               RideRadarPassPoint(id: 0, minutes: 1.2, distance: 42, isHighTier: false),
               RideRadarPassPoint(id: 1, minutes: 2.8, distance: 12, isHighTier: true),
               RideRadarPassPoint(id: 2, minutes: 4.1, distance: 65, isHighTier: false),
               RideRadarPassPoint(id: 3, minutes: 6.9, distance: 30, isHighTier: false),
               RideRadarPassPoint(id: 4, minutes: 8.4, distance: 5, isHighTier: true)
            ],
            radarDistanceUnit: "FT",
            durationMinutes: 11
         )
      )
      .padding()
   }
   .preferredColorScheme(.dark)
}
