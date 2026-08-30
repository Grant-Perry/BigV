//
//  RideWeatherPrecipBarsView.swift
//  BigV
//

import SwiftUI

/// The precipitation columns themselves.
///
/// The scale is absolute: a bar's height is its own share of a full 0…100%
/// plot, never its share of the tallest bar on screen. Relative scaling makes a
/// 4% drizzle touch the ceiling on a dry day, which is exactly the reading a
/// rider must not get. A dry bar still draws a sliver, so a clear afternoon
/// never reads as missing data — the difference between "no rain" and "no
/// forecast" matters to someone deciding whether to leave.
struct RideWeatherPrecipBarsView: View {

   let bars: [RidePrecipBar]
   let axisMarkers: [RidePrecipAxisMarker]
   var chartHeight: CGFloat = 56

   /// Twelve columns are wide enough to letter; sixty minute bars are not.
   private var isHourly: Bool { bars.count <= RidePrecipForecast.hourCount }

   /// Space held above the plot for the captions, so a 3% bar can draw 3% tall
   /// instead of being inflated to the height of its own label.
   private var captionHeight: CGFloat { isHourly ? 13 : 0 }

   private var plotHeight: CGFloat { max(12, chartHeight - captionHeight) }

   /// Enough of a stub that an empty hour still reads as a measured zero.
   private var baseline: CGFloat { isHourly ? 2 : 1.5 }

   var body: some View {
      VStack(alignment: .leading, spacing: 4) {
         chart
         axis
      }
   }

   // MARK: - Chart

   private var chart: some View {
      ZStack(alignment: .bottom) {
         grid

         HStack(alignment: .bottom, spacing: isHourly ? 3 : 1.1) {
            ForEach(bars) { bar in
               column(for: bar)
            }
         }
      }
      .frame(height: chartHeight)
   }

   private func column(for bar: RidePrecipBar) -> some View {
      let fraction = min(1, max(0, bar.barFill))
      let barHeight = max(baseline, plotHeight * fraction)

      return VStack(spacing: 1.5) {
         Spacer(minLength: 0)

         if isHourly {
            caption(for: bar)
         }

         UnevenRoundedRectangle(
            topLeadingRadius: isHourly ? 3.5 : 2.5,
            bottomLeadingRadius: 0.5,
            bottomTrailingRadius: 0.5,
            topTrailingRadius: isHourly ? 3.5 : 2.5,
            style: .continuous
         )
         .fill(fill(isWet: bar.isWet, fraction: fraction))
         .frame(height: barHeight)
      }
      .frame(maxWidth: .infinity)
      .frame(height: chartHeight, alignment: .bottom)
   }

   /// Sub-threshold chances stay on screen but dimmed: the number is still
   /// worth knowing, it just is not worth shouting.
   private func caption(for bar: RidePrecipBar) -> some View {
      Text(RidePrecipForecast.percentLabel(bar.precipitationChance))
         .font(.system(size: 9, weight: .bold))
         .foregroundStyle(.white.opacity(bar.isWet ? 0.95 : 0.4))
         .lineLimit(1)
         .minimumScaleFactor(0.5)
         .padding(.horizontal, 1)
         .frame(height: captionHeight)
   }

   private func fill(isWet: Bool, fraction: Double) -> LinearGradient {
      LinearGradient(
         colors: [
            RideChromeTokens.ice.opacity(isWet ? 0.95 : 0.30),
            RideDashboardTheme.midnight.opacity(isWet ? 0.78 + 0.18 * fraction : 0.14)
         ],
         startPoint: .top,
         endPoint: .bottom
      )
   }

   // MARK: - Axis

   private var axis: some View {
      GeometryReader { proxy in
         ZStack(alignment: .topLeading) {
            ForEach(axisMarkers) { marker in
               Text(marker.label)
                  .font(.system(size: isHourly ? 11 : 8, weight: .bold))
                  .foregroundStyle(.white.opacity(0.35))
                  .position(x: proxy.size.width * marker.fraction, y: 7)
            }
         }
      }
      .frame(height: isHourly ? 14 : 12)
   }

   // MARK: - Grid

   /// Quarter lines plus a labelled ceiling. Without a stated top, an absolute
   /// scale is indistinguishable from the relative one it replaced.
   private var grid: some View {
      VStack(spacing: 0) {
         ForEach(0..<4, id: \.self) { _ in
            gridLine(opacity: 0.10)
            Spacer(minLength: 0)
         }
         gridLine(opacity: 0.18)
      }
      .frame(height: plotHeight)
      .overlay(alignment: .topTrailing) {
         if isHourly {
            Text("100%")
               .font(.system(size: 7, weight: .bold))
               .foregroundStyle(.white.opacity(0.28))
               .padding(.top, 2)
         }
      }
      .frame(height: chartHeight, alignment: .bottom)
   }

   private func gridLine(opacity: Double) -> some View {
      Rectangle()
         .fill(.white.opacity(opacity))
         .frame(height: 1)
   }
}
