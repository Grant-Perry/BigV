//
//  RideMapFABStack.swift
//  BigV
//

import SwiftUI

/// Search, 3D, satellite and recenter. Inset by the overlay so glass never clips.
struct RideMapFABStack: View {

   let rideMapViewModel: RideMapViewModel
   let onPlanRoute: () -> Void

   var body: some View {
      GlassEffectContainer(spacing: 12) {
         VStack(spacing: 12) {
            HStack(spacing: 12) {
               RideSearchButton(
                  style: .fab,
                  identifier: "map.button.planRoute",
                  action: onPlanRoute
               )

               circleButton(
                  icon: rideMapViewModel.isPitched ? .flatIcon : .pitchedIcon,
                  tint: rideMapViewModel.isPitched ? RideDashboardTheme.ice : .white.opacity(0.85),
                  label: rideMapViewModel.isPitched ? "2D map" : "3D map",
                  identifier: "map.button.pitch",
                  action: rideMapViewModel.togglePitch
               )
            }

            HStack(spacing: 12) {
               circleButton(
                  icon: rideMapViewModel.isSatellite ? .roadIcon : .satelliteIcon,
                  tint: rideMapViewModel.isSatellite ? RideDashboardTheme.ember : .white.opacity(0.85),
                  label: rideMapViewModel.isSatellite ? "Road view" : "Satellite view",
                  identifier: "map.button.imagery",
                  action: rideMapViewModel.toggleSatellite
               )

               cameraModeButton
            }
         }
      }
   }

   // MARK: - Recenter

   private var cameraModeButton: some View {
      let isFollowing = rideMapViewModel.isFollowingRider

      return circleButton(
         icon: isFollowing ? .panIcon : .recenterIcon,
         tint: isFollowing ? .white.opacity(0.8) : RideDashboardTheme.ice,
         label: isFollowing ? "Explore the map" : "Re-center on rider",
         identifier: "map.button.cameraMode",
         action: rideMapViewModel.toggleCameraMode
      )
   }

   private func circleButton(
      icon: String,
      tint: Color,
      label: String,
      identifier: String,
      action: @escaping () -> Void
   ) -> some View {
      Button(action: action) {
         Image(systemName: icon)
            .font(.body.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: RideDashboardTheme.fabSize, height: RideDashboardTheme.fabSize)
            .contentShape(.circle)
      }
      .buttonStyle(.plain)
      .rideGlassChrome(in: Circle())
      .accessibilityLabel(label)
      .accessibilityIdentifier(identifier)
   }
}

private extension String {
   static let panIcon = "arrow.up.and.down.and.arrow.left.and.right"
   static let recenterIcon = "location.fill.viewfinder"
   static let pitchedIcon = "square.stack.3d.up"
   static let flatIcon = "map"
   static let satelliteIcon = "globe.americas.fill"
   static let roadIcon = "road.lanes"
}
