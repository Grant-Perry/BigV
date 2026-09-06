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

// MARK: - Scrim

/// Ground for the footer.
///
/// The footer is a nine-point whisper sitting over whatever the rider is
/// scrolling, so without this the last card's text runs straight through it. A
/// fade rather than a fill — a hard edge would read as a shelf — and the same
/// gradient already lands the pinned Start Riding button.
private struct RideAppFooterScrim: View {

   var body: some View {
      LinearGradient(
         colors: [
            RideDashboardTheme.void.opacity(0),
            RideDashboardTheme.void.opacity(0.70),
            RideDashboardTheme.void.opacity(0.92)
         ],
         startPoint: .top,
         endPoint: .bottom
      )
      // Pulled up past the type so the fade has begun by the time it reaches
      // the words, and out of hit testing so a drag down here still scrolls.
      .padding(.top, -16)
      .allowsHitTesting(false)
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
            .background { RideAppFooterScrim() }
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
