//
//  RideAppFooterView.swift
//  BigV
//

import SwiftUI

/// Version and attribution whisper. Sits in the bottom safe area of every tab,
/// above the tab bar, never over content the rider is reading.
struct RideAppFooterView: View {

   /// The cockpit pays for every point of height it gives up, so it gets one
   /// line. Scrolling surfaces can afford the two-line form.
   enum Style: Sendable {
      case full
      case compact
   }

   var style: Style = .full

   var body: some View {
      Group {
         switch style {
            case .full:
               VStack(spacing: 2) {
                  Text(AppConstants.appVersionLine)
                  Text(AppConstants.copyrightLine)
               }
               .font(.system(size: 9, weight: .regular))

            case .compact:
               Text(AppConstants.compactFooterLine)
                  .font(.system(size: 8, weight: .regular))
                  .lineLimit(1)
                  .minimumScaleFactor(0.75)
         }
      }
      .multilineTextAlignment(.center)
      .foregroundStyle(RideDashboardTheme.ink(0.34))
      .frame(maxWidth: .infinity)
      .accessibilityElement(children: .combine)
      .accessibilityLabel("\(AppConstants.appVersionLine). \(AppConstants.copyrightLine)")
   }
}

extension View {

   /// Adds the version/copyright footer below a tab's content. Applied to the
   /// tab root — including a `NavigationStack` — so pushed screens carry it too.
   func rideAppFooter(_ style: RideAppFooterView.Style = .full) -> some View {
      safeAreaInset(edge: .bottom, spacing: 0) {
         RideAppFooterView(style: style)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 2)
      }
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      VStack(spacing: 24) {
         RideAppFooterView()
         RideAppFooterView(style: .compact)
      }
   }
   .preferredColorScheme(.dark)
}
