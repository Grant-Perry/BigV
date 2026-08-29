//
//  RideWeatherForecastCard.swift
//  BigV
//

import SwiftUI

/// Hourly strip or three-day columns. The header toggles between them, because
/// a rider setting off now and one picking a day want different windows.
struct RideWeatherForecastCard: View {

   private enum Mode: Equatable {
      case hourly
      case threeDay
   }

   let hours: [RideWeatherHour]
   let daily: [RideWeatherDay]
   let unit: RideTemperatureUnit

   @State private var mode: Mode = .hourly

   var body: some View {
      TimelineView(.periodic(from: .now, by: 60)) { context in
         card(at: context.date)
      }
   }

   // MARK: - Card

   private func card(at now: Date) -> some View {
      VStack(alignment: .leading, spacing: 12) {
         header

         Group {
            switch mode {
               case .hourly: hourlyStrip(at: now)
               case .threeDay: dayColumns
            }
         }
         .id(mode)
         .transition(.opacity)
      }
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .rideGlassCard()
      .accessibilityElement(children: .contain)
   }

   private var header: some View {
      Button {
         withAnimation(.easeInOut(duration: 0.22)) {
            mode = mode == .hourly ? .threeDay : .hourly
         }
      } label: {
         HStack(spacing: 5) {
            Text(mode == .hourly ? "Hourly Forecast" : "3-Day Forecast")
               .font(.subheadline.weight(.bold))
               .foregroundStyle(.white)
               .contentTransition(.opacity)

            Image(systemName: "chevron.up.chevron.down")
               .font(.system(size: 11, weight: .bold))
               .foregroundStyle(.white.opacity(0.35))

            Spacer(minLength: 0)
         }
         .padding(.horizontal, 14)
         .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(mode == .hourly ? "Hourly forecast" : "3-day forecast")
      .accessibilityHint(mode == .hourly ? "Shows the 3-day forecast" : "Shows the hourly forecast")
   }

   // MARK: - Hourly

   @ViewBuilder
   private func hourlyStrip(at now: Date) -> some View {
      let visible = visibleHours(at: now)

      if visible.isEmpty {
         unavailable("Hourly forecast unavailable")
      } else {
         ScrollView(.horizontal) {
            HStack(spacing: 10) {
               ForEach(visible) { hour in
                  hourPill(hour)
               }
            }
            .padding(.horizontal, 14)
         }
         .scrollIndicators(.hidden)
      }
   }

   private func hourPill(_ hour: RideWeatherHour) -> some View {
      VStack(spacing: 6) {
         Text(hour.date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated))))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.5))
            .lineLimit(1)
            .minimumScaleFactor(0.7)

         Image(systemName: hour.symbolName)
            .font(.system(size: 20))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white)
            .frame(height: 22)

         Text(RideFormatters.temperatureDegrees(hour.temperatureCelsius, unit: unit))
            .font(.system(size: 15, weight: .semibold).monospacedDigit())
            .foregroundStyle(.white)

         if hour.precipitationChance > 0.05 {
            Text(percent(hour.precipitationChance))
               .font(.system(size: 10, weight: .semibold).monospacedDigit())
               .foregroundStyle(RideChromeTokens.ice)
         } else {
            Color.clear.frame(height: 12)
         }
      }
      .frame(width: 58)
      .padding(.vertical, 10)
      .rideGlassCard(density: .standard, cornerRadius: 14)
   }

   private func visibleHours(at now: Date) -> [RideWeatherHour] {
      let currentHour = Calendar.current.dateInterval(of: .hour, for: now)?.start ?? now
      return Array(hours.lazy.filter { $0.date >= currentHour }.prefix(24))
   }

   // MARK: - Three Day

   @ViewBuilder
   private var dayColumns: some View {
      if daily.isEmpty {
         unavailable("Daily forecast unavailable")
      } else {
         HStack(spacing: 12) {
            ForEach(daily.prefix(3)) { day in
               dayColumn(day)
            }
         }
         .padding(.horizontal, 14)
         .padding(.bottom, 4)
      }
   }

   private func dayColumn(_ day: RideWeatherDay) -> some View {
      VStack(spacing: 4) {
         Text(dayLabel(for: day.calendarDayStart))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

         Image(systemName: day.symbolName)
            .font(.system(size: 22))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white)
            .frame(height: 24)

         Text(day.precipitationChance >= 0.05 ? percent(day.precipitationChance) : "—")
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(day.precipitationChance >= 0.05 ? 0.55 : 0.3))

         HStack(spacing: 4) {
            Text(RideFormatters.temperatureDegrees(day.lowCelsius, unit: unit))
               .font(.system(size: 15, weight: .regular).monospacedDigit())
               .foregroundStyle(.white.opacity(0.55))

            Text(RideFormatters.temperatureDegrees(day.highCelsius, unit: unit))
               .font(.system(size: 18, weight: .bold).monospacedDigit())
               .foregroundStyle(.white)
         }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
   }

   private func dayLabel(for date: Date) -> String {
      let calendar = Calendar.current
      if calendar.isDateInToday(date) { return "Today" }
      if calendar.isDateInTomorrow(date) { return "Tomorrow" }
      return date.formatted(.dateTime.weekday(.abbreviated))
   }

   // MARK: - Pieces

   private func unavailable(_ message: String) -> some View {
      Text(message)
         .font(.subheadline)
         .foregroundStyle(.white.opacity(0.45))
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(.horizontal, 14)
         .padding(.vertical, 8)
   }

   private func percent(_ chance: Double) -> String {
      "\(Int((chance * 100).rounded()))%"
   }
}
