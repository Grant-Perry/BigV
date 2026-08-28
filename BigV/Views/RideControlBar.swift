//
//  RideControlBar.swift
//  BigV
//

import SwiftUI

/// Start, pause, resume and end as a glass dock over the map.
struct RideControlBar: View {

   let rideViewModel: RideViewModel

   var body: some View {
      HStack(spacing: 16) {
         switch rideViewModel.phase {
            case .idle:
               control("START", icon: .startIcon, tint: RideDashboardTheme.go, action: rideViewModel.start)

            case .acquiringGPS:
               control("CANCEL", icon: .cancelIcon, tint: RideDashboardTheme.halt, action: rideViewModel.end)

            case .recording:
               control("PAUSE", icon: .pauseIcon, tint: RideDashboardTheme.pause, action: rideViewModel.pause)
               control("END", icon: .endIcon, tint: RideDashboardTheme.halt, action: rideViewModel.end)

            case .paused:
               control("RESUME", icon: .startIcon, tint: RideDashboardTheme.go, action: rideViewModel.resume)
               control("END", icon: .endIcon, tint: RideDashboardTheme.halt, action: rideViewModel.end)

            case .finished:
               control("NEW RIDE", icon: .newRideIcon, tint: RideDashboardTheme.ice, action: rideViewModel.reset)
         }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 7)
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
            .font(.body.weight(.bold))
            .foregroundStyle(.white.opacity(0.95))
            .frame(width: 44, height: 44)
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
   static let cancelIcon = "xmark"
   static let newRideIcon = "plus"
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      RideControlBar(rideViewModel: RideViewModel())
   }
}
