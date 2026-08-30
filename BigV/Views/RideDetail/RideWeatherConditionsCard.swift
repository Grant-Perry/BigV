//
//  RideWeatherConditionsCard.swift
//  BigV
//

import SwiftUI

/// The sky this ride was ridden under: condition, the temperature at rollout
/// (and at the finish when it moved), feels-like and wind.
struct RideWeatherConditionsCard: View {

   let report: RideDetailWeatherReport

   var body: some View {
      VStack(alignment: .leading, spacing: 12) {
         RideDetailCardHeader(
            icon: "cloud.sun.fill",
            tint: RideDashboardTheme.amber,
            title: "CONDITIONS"
         )

         HStack(spacing: 14) {
            Image(systemName: report.symbolName)
               .font(.system(size: 34))
               .symbolVariant(.fill)
               .symbolRenderingMode(.multicolor)
               .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
               Text(report.conditionLabel)
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(.white)
                  .lineLimit(1)
                  .minimumScaleFactor(0.8)

               if let feelsLike = report.feelsLikeText {
                  Text(feelsLike)
                     .font(.caption.weight(.medium))
                     .foregroundStyle(.white.opacity(0.5))
               }

               if let wind = report.windText {
                  Text(wind)
                     .font(.caption.weight(.medium))
                     .foregroundStyle(.white.opacity(0.5))
               }
            }

            Spacer(minLength: 8)

            Text(report.temperatureText)
               .font(.system(size: 30, weight: .semibold, design: .rounded))
               .monospacedDigit()
               .foregroundStyle(.white)
               .lineLimit(1)
               .minimumScaleFactor(0.6)
         }
         .accessibilityElement(children: .combine)
         .accessibilityLabel("Weather")
         .accessibilityValue("\(report.conditionLabel), \(report.temperatureText)")
      }
      .padding(14)
      .rideGlassCard(density: .standard)
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground(scene: .summary)
      RideWeatherConditionsCard(
         report: RideDetailWeatherReport(
            symbolName: "sun.max.fill",
            conditionLabel: "Mostly Sunny",
            temperatureText: "64° → 68°",
            feelsLikeText: "Feels 61°",
            windText: "9 mph wind"
         )
      )
      .padding()
   }
   .preferredColorScheme(.dark)
}
