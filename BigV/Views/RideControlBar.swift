//
//  RideControlBar.swift
//  BigV

import SwiftUI

/// Start, pause, resume and end as a glass dock over the map.
struct RideControlBar: View {

   // MARK: - Style

   /// How much room the dock is allowed to take.
   ///
   /// `.compact` is what rides over the live map. The dock used to run the full
   /// width of the drawer on 44-point buttons, which put the controls across the
   /// middle of a map only 190 points tall — the rider could reach START but
   /// could not see the road it was drawn over. Compact parks in one corner and
   /// leaves the map readable.
   enum Style {

      case full
      case compact

      var controlSize: CGFloat {
         switch self {
            case .full: 44
            case .compact: 34
         }
      }

      var spacing: CGFloat {
         switch self {
            case .full: 16
            case .compact: 8
         }
      }

      var horizontalPadding: CGFloat {
         switch self {
            case .full: 14
            case .compact: 7
         }
      }

      var verticalPadding: CGFloat {
         switch self {
            case .full: 7
            case .compact: 5
         }
      }

      var iconFont: Font {
         switch self {
            case .full: .body.weight(.bold)
            case .compact: .footnote.weight(.bold)
         }
      }
   }

   let rideViewModel: RideViewModel
   var style: Style = .full

   var body: some View {
      HStack(spacing: style.spacing) {
         switch rideViewModel.phase {
            case .idle:
               control("START", icon: .startIcon, tint: RideDashboardTheme.go, action: rideViewModel.start)

            case .acquiringGPS:
               control("CANCEL", icon: .cancelIcon, tint: RideDashboardTheme.halt, action: rideViewModel.end)

            case .recording:
               control("PAUSE", icon: .pauseIcon, tint: RideDashboardTheme.pause, action: rideViewModel.pause)
               control("LAP", icon: .lapIcon, tint: RideDashboardTheme.ice, action: rideViewModel.lap)
               control("END", icon: .endIcon, tint: RideDashboardTheme.halt, action: rideViewModel.end)

            case .paused:
               control("RESUME", icon: .startIcon, tint: RideDashboardTheme.go, action: rideViewModel.resume)
               control("END", icon: .endIcon, tint: RideDashboardTheme.halt, action: rideViewModel.end)

            case .finished:
               control("NEW RIDE", icon: .newRideIcon, tint: RideDashboardTheme.ice, action: rideViewModel.reset)
         }
      }
      .padding(.horizontal, style.horizontalPadding)
      .padding(.vertical, style.verticalPadding)
      .rideGlassChrome(in: .capsule)
   }

   // MARK: - Control

   private func control(
      _ title: String,
      icon: String,
      tint: Color,
      isEnabled: Bool = true,
      action: @escaping () -> Void
   ) -> some View {
      Button(action: action) {
         Image(systemName: icon)
            .font(style.iconFont)
            .foregroundStyle(RideDashboardTheme.ink(0.95))
            .frame(width: style.controlSize, height: style.controlSize)
            .background {
               Circle()
                  .fill(
                     LinearGradient(
                        colors: [tint.opacity(0.40), tint.opacity(0.16)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                     )
                  )
            }
            .contentShape(.circle)
      }
      .buttonStyle(.plain)
      .disabled(!isEnabled)
      .accessibilityLabel(title)
      .accessibilityIdentifier(title)
   }
}

private extension String {
   static let startIcon = "play.fill"
   static let pauseIcon = "pause.fill"
   static let endIcon = "stop.fill"
   static let lapIcon = "flag.fill"
   static let cancelIcon = "xmark"
   static let newRideIcon = "plus"
}

#Preview {
   ZStack {
      RideAtmosphereBackground()

      VStack(spacing: 24) {
         RideControlBar(rideViewModel: RideViewModel())
         RideControlBar(rideViewModel: RideViewModel(), style: .compact)
      }
   }
}
