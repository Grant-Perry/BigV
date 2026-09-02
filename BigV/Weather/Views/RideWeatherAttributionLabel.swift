//
//  RideWeatherAttributionLabel.swift
//  BigV
//

import SwiftUI

/// Apple Weather attribution.
///
/// Not decoration: the WeatherKit terms require the source to be named and the
/// legal page to be reachable anywhere its data is shown. The link falls back to
/// Apple's published page when the service has not yet handed one over, so the
/// footer is never missing.
struct RideWeatherAttributionLabel: View {

   var url: URL?

   private static let legalPage = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

   var body: some View {
      Link(destination: url ?? Self.legalPage) {
         Text("Weather data · Apple Weather")
            .font(.caption2)
            .foregroundStyle(RideDashboardTheme.ink(0.4))
      }
      .accessibilityLabel("Weather data from Apple Weather")
      .accessibilityHint("Opens Apple's weather data sources page")
   }
}
