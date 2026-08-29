//
//  RideWeatherPrecipBarsView.swift
//  BigV
//

import SwiftUI

/// The precipitation columns themselves.
///
/// A dry bar still draws a sliver, so a clear afternoon never reads as missing
/// data — the difference between "no rain" and "no forecast" matters to someone
/// deciding whether to leave.
struct RideWeatherPrecipBarsView: View {

   let bars: [RidePrecipBar]
   let axisMarkers: [RidePrecipAxisMarker]
   var chartHeight: CGFloat = 48

   /// Twelve columns are wide enough to letter; sixty minute bars are not.
   private var isHourly: Bool { bars.count <= RidePrecipForecast.hourCount }

   /// Never scale against a trivially small maximum, or a 3% drizzle fills the
   /// chart and looks like a downpour.
   private var maxFill: Double { max(bars.map(\.barFill).max() ?? 0, 0.12) }

   var body: some View {
      VStack(alignment: .leading, spacing: 4) {
         chart
         axis
      }
   }

   // MARK: - Chart

   private var chart: some View {
      GeometryReader { proxy in
         ZStack(alignment: .bottomLeading) {
            thresholdLines

            HStack(alignment: .bottom, spacing: isHourly ? 3 : 1.1) {
               ForEach(bars) { bar in
                  column(for: bar, height: proxy.size.height)
               }
            }
         }
      }
      .frame(height: chartHeight)
   }

   private func column(for bar: RidePrecipBar, height: CGFloat) -> some View {
      let normalized = min(1, bar.barFill / maxFill)
      let floor: CGFloat = isHourly ? 16 : (bar.isWet ? 6 : 1.5)
      let barHeight = bar.isWet
         ? max(floor, normalized * height)
         : (isHourly ? floor : max(floor, 0.06 * height))

      return ZStack(alignment: .bottom) {
         UnevenRoundedRectangle(
            topLeadingRadius: isHourly ? 3.5 : 2.5,
            bottomLeadingRadius: 0.5,
            bottomTrailingRadius: 0.5,
            topTrailingRadius: isHourly ? 3.5 : 2.5,
            style: .continuous
         )
         .fill(fill(isWet: bar.isWet, normalized: normalized))

         if isHourly {
            Text("\(Int((bar.precipitationChance * 100).rounded()))%")
               .font(.system(size: 9, weight: .bold))
               .foregroundStyle(.white)
               .lineLimit(1)
               .minimumScaleFactor(0.45)
               .shadow(color: .black.opacity(0.35), radius: 1, y: 0.5)
               .padding(.bottom, 2)
               .padding(.horizontal, 1)
         }
      }
      .frame(maxWidth: .infinity)
      .frame(height: barHeight)
      .frame(maxHeight: .infinity, alignment: .bottom)
   }

   private func fill(isWet: Bool, normalized: Double) -> LinearGradient {
      LinearGradient(
         colors: [
            RideChromeTokens.ice.opacity(isWet ? 0.95 + 0.05 * normalized : 0.22),
            RideDashboardTheme.midnight.opacity(isWet ? 0.78 + 0.18 * normalized : 0.10)
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

   private var thresholdLines: some View {
      VStack(spacing: 0) {
         ForEach(0..<3) { _ in
            Spacer()
            dashedLine
         }
         Spacer()
      }
   }

   private var dashedLine: some View {
      Rectangle()
         .fill(.white.opacity(0.12))
         .frame(height: 1)
   }
}
