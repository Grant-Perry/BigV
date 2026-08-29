//
//  RideWeatherSunCard.swift
//  BigV
//

import SwiftUI

/// Sunrise and sunset — the two times that decide whether a rider needs lights.
struct RideWeatherSunCard: View {

   let today: RideWeatherDay?

   var body: some View {
      HStack(spacing: 0) {
         sunBlock(
            title: "Sunrise",
            systemImage: "sunrise.fill",
            date: today?.sunrise,
            tint: RideChromeTokens.ice
         )

         Divider()
            .frame(height: 44)
            .overlay(.white.opacity(0.1))
            .padding(.horizontal, 8)

         sunBlock(
            title: "Sunset",
            systemImage: "sunset.fill",
            date: today?.sunset,
            tint: RideChromeTokens.amber
         )
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity)
      .rideGlassCard()
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Sunrise \(label(today?.sunrise)), sunset \(label(today?.sunset))")
   }

   // MARK: - Blocks

   private func sunBlock(
      title: String,
      systemImage: String,
      date: Date?,
      tint: Color
   ) -> some View {
      HStack(spacing: 10) {
         Image(systemName: systemImage)
            .font(.title3.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: 28)

         VStack(alignment: .leading, spacing: 2) {
            Text(title)
               .font(.caption.weight(.semibold))
               .foregroundStyle(.white.opacity(0.5))

            Text(label(date))
               .font(.headline.monospacedDigit())
               .foregroundStyle(.white)
         }

         Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
   }

   private func label(_ date: Date?) -> String {
      guard let date else { return RideFormatters.placeholder }
      return date.formatted(date: .omitted, time: .shortened)
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      RideWeatherSunCard(
         today: RideWeatherDay(
            calendarDayStart: .now,
            conditionSymbolName: "sun.max.fill",
            conditionLabel: "Clear",
            highCelsius: 26,
            lowCelsius: 14,
            precipitationChance: 0.1,
            sunrise: .now,
            sunset: .now.addingTimeInterval(43_200)
         )
      )
      .padding()
   }
}
