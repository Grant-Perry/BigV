//
//  RideHistoryHeroCard.swift
//  BigV
//

import SwiftUI

/// Cinematic latest-ride card for the Rides landing page.
struct RideHistoryHeroCard: View {

   let row: RideHistoryViewModel.Row
   let distanceUnit: String
   let route: RideRoute
   let isRouteLoaded: Bool

   var body: some View {
      VStack(alignment: .leading, spacing: 0) {
         RideRouteMapView(
            route: route,
            isLoaded: isRouteLoaded,
            height: 196
         )
         .clipShape(.rect(cornerRadius: 16, style: .continuous))
         .padding(8)

         VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
               Text("LATEST RIDE")
                  .font(.caption2.weight(.bold))
                  .kerning(1.4)
                  .foregroundStyle(RideDashboardTheme.ember)

               Text(row.dateText)
                  .font(.title3.weight(.semibold))
                  .foregroundStyle(.white)
            }

            HStack(spacing: 0) {
               heroStat(row.distanceText, unit: distanceUnit, title: "DISTANCE")
               heroStat(row.durationText, unit: nil, title: "TIME")
               heroStat(row.averageSpeedText, unit: RideFormatters.Unit.speed, title: "AVG")
               heroStat(row.maximumSpeedText, unit: RideFormatters.Unit.speed, title: "MAX")
            }
         }
         .padding(.horizontal, 16)
         .padding(.bottom, 16)
      }
      .rideGlassCard(density: .standard, cornerRadius: 22)
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Latest ride \(row.dateText)")
      .accessibilityValue("\(row.distanceText) \(distanceUnit), \(row.durationText)")
   }

   // MARK: - Stat

   private func heroStat(_ value: String, unit: String?, title: String) -> some View {
      VStack(alignment: .leading, spacing: 2) {
         Text(title)
            .font(.caption2.weight(.semibold))
            .kerning(0.8)
            .foregroundStyle(.white.opacity(0.42))

         HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
               .font(.system(size: 20, weight: .semibold, design: .rounded))
               .monospacedDigit()
               .foregroundStyle(.white)

            if let unit {
               Text(unit)
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(.white.opacity(0.45))
            }
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
   }
}
