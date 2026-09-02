//
//  RideWeatherPrecipCard.swift
//  BigV
//

import SwiftUI

/// Precipitation ahead: twelve hours by default, the next hour minute by minute
/// on tap. The whole card is the control — a rider checking rain is not aiming
/// at a small target.
struct RideWeatherPrecipCard: View {

   private enum Mode: Equatable {
      case next12Hours
      case nextHour
   }

   let outlook: RidePrecipOutlook

   @State private var mode: Mode = .next12Hours

   var body: some View {
      TimelineView(.periodic(from: .now, by: 60)) { context in
         card(at: context.date)
      }
   }

   // MARK: - Card

   private func card(at now: Date) -> some View {
      let bars = bars(at: now)
      let title = title(for: bars)
      let summary = summary(for: bars, at: now)

      return VStack(alignment: .leading, spacing: 6) {
         HStack(spacing: 5) {
            Text(title)
               .font(.system(size: 13, weight: .bold))
               .foregroundStyle(RideDashboardTheme.ink)
               .lineLimit(1)
               .minimumScaleFactor(0.75)
               .contentTransition(.opacity)

            Image(systemName: "chevron.up.chevron.down")
               .font(.system(size: 10, weight: .bold))
               .foregroundStyle(RideDashboardTheme.ink(0.35))

            Spacer(minLength: 0)
         }

         Text(summary)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(RideDashboardTheme.ink(0.55))
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .contentTransition(.opacity)

         chart(bars)
            .id(mode)
            .transition(.opacity)
            .padding(.top, 4)
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .topLeading)
      .rideGlassCard()
      .contentShape(.rect)
      .onTapGesture { toggle() }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(title). \(summary)")
      .accessibilityHint("Switches between the next 12 hours and the next hour")
      .accessibilityAddTraits(.isButton)
      .accessibilityAction { toggle() }
   }

   @ViewBuilder
   private func chart(_ bars: [RidePrecipBar]) -> some View {
      if bars.isEmpty {
         Text("Precipitation chart unavailable")
            .font(.caption)
            .foregroundStyle(RideDashboardTheme.ink(0.45))
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
      } else {
         RideWeatherPrecipBarsView(bars: bars, axisMarkers: axisMarkers(for: bars))
      }
   }

   // MARK: - Data

   private func bars(at now: Date) -> [RidePrecipBar] {
      switch mode {
         case .next12Hours:
            RidePrecipForecast.hourlyBars(hours: outlook.hours, anchor: now)

         case .nextHour:
            RidePrecipForecast.minuteBars(
               minutes: outlook.minutes,
               hourlyFallback: outlook.hours,
               now: now
            )
      }
   }

   private func axisMarkers(for bars: [RidePrecipBar]) -> [RidePrecipAxisMarker] {
      switch mode {
         case .next12Hours: RidePrecipForecast.hourlyAxisMarkers(for: bars)
         case .nextHour: RidePrecipForecast.minuteAxisMarkers
      }
   }

   private func title(for bars: [RidePrecipBar]) -> String {
      switch mode {
         case .next12Hours: RidePrecipForecast.hourlyTitle
         case .nextHour: RidePrecipForecast.nextHourTitle(minuteBars: bars)
      }
   }

   private func summary(for bars: [RidePrecipBar], at now: Date) -> String {
      switch mode {
         case .next12Hours: RidePrecipForecast.hourlySummary(bars: bars, now: now)
         case .nextHour: RidePrecipForecast.nextHourSummary(minuteBars: bars, now: now)
      }
   }

   // MARK: - Mode

   private func toggle() {
      withAnimation(.easeInOut(duration: 0.22)) {
         mode = mode == .next12Hours ? .nextHour : .next12Hours
      }
   }
}
