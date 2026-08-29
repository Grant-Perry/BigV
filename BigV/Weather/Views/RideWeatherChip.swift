//
//  RideWeatherChip.swift
//  BigV
//

import SwiftUI

/// The sky's seat on the status row, mirroring `RideHeartRateChip`: a condition
/// glyph and the temperature, nothing else. Tapping it opens the full forecast.
///
/// It owns its sheet rather than reporting a tap upward, because unlike radar
/// and setup this is the only door into weather — routing it through the root
/// would buy nothing but four more closures.
struct RideWeatherChip: View {

   @Environment(RideWeatherModel.self) private var rideWeatherModel
   @Environment(\.scenePhase) private var scenePhase

   @State private var isShowingForecast = false

   var body: some View {
      Button {
         isShowingForecast = true
      } label: {
         if let snapshot = rideWeatherModel.snapshot {
            reading(snapshot)
         } else {
            placeholder
         }
      }
      .buttonStyle(.plain)
      .rideGlassChrome(in: Capsule())
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Weather")
      .accessibilityValue(accessibilityValue)
      .accessibilityHint("Opens the forecast")
      .accessibilityIdentifier("ride.chip.weather")
      .task { await rideWeatherModel.runRefreshLoop() }
      .onChange(of: scenePhase) { _, phase in
         guard phase == .active else { return }
         Task { await rideWeatherModel.refreshIfStale() }
      }
      .sheet(isPresented: $isShowingForecast) {
         RideWeatherDetailSheet(rideWeatherModel: rideWeatherModel)
      }
   }

   // MARK: - Reading

   private func reading(_ snapshot: RideWeatherSnapshot) -> some View {
      HStack(spacing: 6) {
         Image(systemName: snapshot.symbolName)
            .font(.caption.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(RideChromeTokens.ice)

         Text(
            RideFormatters.temperatureDegrees(
               snapshot.temperatureCelsius,
               unit: rideWeatherModel.temperatureUnit
            )
         )
         .font(.caption.weight(.bold))
         .monospacedDigit()
         .foregroundStyle(.white)
      }
      .padding(.horizontal, 12)
      .frame(height: 36)
      .contentShape(.capsule)
   }

   // MARK: - Degraded

   /// No reading yet, or none to be had. A glyph-only circle keeps the row from
   /// carrying a dead pill while still leaving the forecast one tap away, where
   /// the reason — and the permission prompt — live.
   private var placeholder: some View {
      Image(systemName: rideWeatherModel.isLoading ? .pendingIcon : .absentIcon)
         .font(.caption.weight(.semibold))
         .symbolRenderingMode(.hierarchical)
         .foregroundStyle(.white.opacity(0.4))
         .frame(width: 36, height: 36)
         .contentShape(.circle)
   }

   // MARK: - Accessibility

   private var accessibilityValue: String {
      guard let snapshot = rideWeatherModel.snapshot else {
         return rideWeatherModel.isLoading ? "Loading" : "Unavailable"
      }

      let temperature = RideFormatters.temperature(
         snapshot.temperatureCelsius,
         unit: rideWeatherModel.temperatureUnit
      )
      return "\(snapshot.conditionLabel), \(temperature)"
   }
}

private extension String {
   static let pendingIcon = "cloud"
   static let absentIcon = "cloud.slash"
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      RideWeatherChip()
         .padding()
   }
   .environment(RideWeatherModel(unitsSettings: RideUnitsSettings()))
}
