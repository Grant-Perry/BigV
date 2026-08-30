//
//  RideHistoryHeroCard.swift
//  BigV
//

import SwiftUI

/// Cinematic latest-ride card for the Rides landing page.
///
/// Reads as an invitation, not a poster: the map wears a legend so its dots
/// explain themselves, the header carries the ride's stored sky, and the
/// footer says out loud that a full report is one tap away.
struct RideHistoryHeroCard: View {

   let row: RideHistoryViewModel.Row
   let distanceUnit: String
   let route: RideRoute
   let isRouteLoaded: Bool

   var body: some View {
      VStack(alignment: .leading, spacing: 0) {
         map

         VStack(alignment: .leading, spacing: 12) {
            header
            statRow

            if row.vehicleCount > 0 {
               vehiclesLine
            }

            reportFooter
         }
         .padding(.horizontal, 16)
         .padding(.bottom, 14)
      }
      .rideGlassCard(density: .standard, cornerRadius: 22)
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Latest ride \(row.dateText)")
      .accessibilityValue("\(row.distanceText) \(distanceUnit), \(row.durationText)")
      .accessibilityHint("Opens the full ride report")
   }

   // MARK: - Map

   private var map: some View {
      RideRouteMapView(
         route: route,
         isLoaded: isRouteLoaded,
         height: 196
      )
      .clipShape(.rect(cornerRadius: 16, style: .continuous))
      .overlay(alignment: .topLeading) {
         if route.isDrawable {
            RideRouteMapLegend(showsVehicles: false)
               .padding(8)
         }
      }
      .padding(8)
   }

   // MARK: - Header

   private var header: some View {
      HStack(alignment: .top) {
         VStack(alignment: .leading, spacing: 3) {
            Text("LATEST RIDE")
               .font(.caption2.weight(.bold))
               .kerning(1.4)
               .foregroundStyle(RideDashboardTheme.ember)

            Text(row.dateText)
               .font(.title3.weight(.semibold))
               .foregroundStyle(.white)
         }

         Spacer(minLength: 8)

         if let symbolName = row.weatherSymbolName, let temperature = row.temperatureText {
            HStack(spacing: 5) {
               Image(systemName: symbolName)
                  .font(.subheadline)
                  .symbolVariant(.fill)
                  .symbolRenderingMode(.multicolor)

               Text(temperature)
                  .font(.subheadline.weight(.semibold))
                  .monospacedDigit()
                  .foregroundStyle(.white.opacity(0.75))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Weather \(temperature)")
         }
      }
   }

   // MARK: - Stats

   private var statRow: some View {
      HStack(spacing: 0) {
         heroStat(row.distanceText, unit: distanceUnit, title: "DISTANCE")
         heroStat(row.durationText, unit: nil, title: "TIME")
         heroStat(row.averageSpeedText, unit: row.speedUnit, title: "AVG")
         heroStat(row.maximumSpeedText, unit: row.speedUnit, title: "MAX")
      }
   }

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

   // MARK: - Vehicles

   private var vehiclesLine: some View {
      HStack(spacing: 6) {
         Image(systemName: "car.rear.fill")
            .font(.caption2)
            .foregroundStyle(RideChromeTokens.amber)

         Text("\(row.vehicleCount) vehicle\(row.vehicleCount == 1 ? "" : "s") tracked by radar")
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.55))
      }
      .accessibilityElement(children: .combine)
   }

   // MARK: - Footer

   /// The card is a navigation link; this line makes sure nobody has to
   /// discover that by accident.
   private var reportFooter: some View {
      VStack(spacing: 10) {
         Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 1)

         HStack {
            Text("VIEW FULL REPORT")
               .font(.caption2.weight(.bold))
               .kerning(1.2)
               .foregroundStyle(RideDashboardTheme.ember)

            Spacer()

            Image(systemName: "chevron.right")
               .font(.caption2.weight(.bold))
               .foregroundStyle(RideDashboardTheme.ember.opacity(0.8))
         }
      }
   }
}

