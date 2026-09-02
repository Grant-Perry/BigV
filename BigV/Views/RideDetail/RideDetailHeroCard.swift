//
//  RideDetailHeroCard.swift
//  BigV
//

import SwiftUI

/// The ride's headline: when it happened, how far it went, and the four
/// numbers a rider quotes afterward. This is the card people screenshot.
struct RideDetailHeroCard: View {

   let header: RideDetailHeader

   var body: some View {
      VStack(alignment: .leading, spacing: 14) {
         dateline
         distanceHero
         statRow
      }
      .padding(16)
      .rideGlassCard(density: .standard)
   }

   // MARK: - Dateline

   private var dateline: some View {
      HStack(alignment: .firstTextBaseline) {
         Text(header.dateText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(RideDashboardTheme.ink(0.6))
            .lineLimit(1)
            .minimumScaleFactor(0.8)

         Spacer(minLength: 8)

         Text(header.timeRangeText)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(RideDashboardTheme.ice.opacity(0.85))
            .lineLimit(1)
      }
   }

   // MARK: - Distance

   private var distanceHero: some View {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
         Text(header.distance)
            .font(.system(size: 56, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(RideDashboardTheme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)

         Text(header.distanceUnit)
            .font(.headline.weight(.semibold))
            .foregroundStyle(RideDashboardTheme.ink(0.45))
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Distance")
      .accessibilityValue("\(header.distance) \(header.distanceUnit)")
   }

   // MARK: - Stats

   private var statRow: some View {
      HStack(spacing: 8) {
         RideDetailFootnoteStat(label: "RIDE TIME", value: header.rideTime)
         RideDetailFootnoteStat(label: "MOVING", value: header.movingTime)
         RideDetailFootnoteStat(label: "STOPPED", value: header.stoppedTime)
         RideDetailFootnoteStat(
            label: "AVG SPEED",
            value: header.averageSpeed,
            unit: header.speedUnit,
            tint: RideDashboardTheme.ice
         )
      }
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground(scene: .summary)
      RideDetailHeroCard(
         header: RideDetailHeader(
            dateText: "Saturday, August 29, 2026",
            timeRangeText: "9:08 AM – 9:19 AM",
            distance: "2.96",
            distanceUnit: "MI",
            rideTime: "11:04",
            movingTime: "9:15",
            stoppedTime: "1:49",
            averageSpeed: "19.2",
            speedUnit: "MPH"
         )
      )
      .padding()
   }
   .preferredColorScheme(.dark)
}
