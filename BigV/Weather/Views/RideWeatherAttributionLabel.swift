//
//  RideWeatherAttributionLabel.swift
//  BigV
//

import SwiftUI

/// The Apple Weather trademark, linked to Apple's legal attribution page.
///
/// WeatherKit requires the  Weather mark itself wherever its data is shown,
/// plus a way to open the legal sources. The artwork is Apple's combined mark.
/// The link prefers the URL WeatherKit handed back for this session, then the
/// page Apple publishes for that mark.
struct RideWeatherAttributionLabel: View {

   enum Style: Sendable {
      case regular
      case compact

      var height: CGFloat {
         switch self {
            case .regular: 20
            case .compact: 14
         }
      }
   }

   var style: Style = .regular

   /// Legal page from the weather response, when this surface already has one.
   var url: URL?

   @State private var resolvedURL: URL?

   private static let legalPage = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!

   var body: some View {
      Link(destination: url ?? resolvedURL ?? Self.legalPage) {
         Image("AppleWeatherMark")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(height: style.height)
            .fixedSize(horizontal: true, vertical: true)
            .accessibilityHidden(true)
      }
      .accessibilityLabel("Apple Weather")
      .accessibilityHint("Opens Apple's weather data sources")
      .task { await resolveLegalPage() }
   }

   /// The bundled mark is already the trademark. This only keeps the link
   /// pointed at the page WeatherKit is currently serving.
   private func resolveLegalPage() async {
      guard url == nil, resolvedURL == nil else { return }
      resolvedURL = await RideWeatherClient.shared.legalPageURL()
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      VStack(spacing: 24) {
         RideWeatherAttributionLabel()
         RideWeatherAttributionLabel(style: .compact)
      }
   }
   .preferredColorScheme(.dark)
}
