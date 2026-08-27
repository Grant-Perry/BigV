//
//  RideMapOverlayView.swift
//  BigV
//

import SwiftUI

/// Live numbers, heading and the re-center control layered over the ride map.
///
/// Speed and distance get full-size tiles because they are what a rider reads at
/// a glance; heading is chrome, so it sits small and out of the way opposite the
/// map compass.
struct RideMapOverlayView: View {

   let rideMapViewModel: RideMapViewModel
   let routeGuidanceViewModel: RouteGuidanceViewModel
   let onPlanRoute: () -> Void

   var body: some View {
      VStack(spacing: 10) {
         if routeGuidanceViewModel.isActive {
            RouteGuidanceBannerView(routeGuidanceViewModel: routeGuidanceViewModel)
         }

         topRow

         Spacer(minLength: 0)

         controls
            .frame(maxWidth: .infinity, alignment: .trailing)

         readouts
      }
      .padding(.horizontal, 12)
      .padding(.top, 12)
      // Clears the map's legal attribution, which App Review requires stay visible.
      .padding(.bottom, 28)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
   }

   // MARK: - Top Row

   private var topRow: some View {
      HStack(alignment: .top, spacing: 8) {
         if let headingDegrees = rideMapViewModel.headingDegrees {
            headingPill(degrees: headingDegrees)
         }

         Spacer(minLength: 0)

         // The banner already names where the rider is going and how to stop, so
         // the chip would only be a second copy competing for the same corner.
         if let destinationName = rideMapViewModel.destinationName,
            !routeGuidanceViewModel.isActive {
            destinationChip(name: destinationName)
         }
      }
   }

   // MARK: - Destination

   /// The one piece of navigation chrome allowed to stay on screen mid-ride:
   /// where the rider is headed, and the only way to stop heading there.
   private func destinationChip(name: String) -> some View {
      HStack(spacing: 8) {
         Image(systemName: .destinationIcon)
            .font(.caption2.weight(.bold))
            .foregroundStyle(PlannedRouteStyle.line)

         Text(name)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(1)

         Button(action: rideMapViewModel.clearPlannedRoute) {
            Image(systemName: .clearRouteIcon)
               .font(.footnote)
               .foregroundStyle(.white.opacity(0.55))
               .frame(width: 28, height: 28)
               .contentShape(.circle)
         }
         .buttonStyle(.plain)
         .accessibilityLabel("Clear planned route")
         .accessibilityIdentifier("map.button.clearRoute")
      }
      .padding(.leading, 12)
      .padding(.trailing, 2)
      .padding(.vertical, 4)
      .background(.black.opacity(0.72), in: .capsule)
      .overlay(Capsule().stroke(PlannedRouteStyle.line.opacity(0.35), lineWidth: 1))
      .frame(maxWidth: 210, alignment: .trailing)
      .accessibilityIdentifier("map.label.destination")
   }

   // MARK: - Controls

   /// Route planning is offered only while idle. A rider under way needs their
   /// numbers, not a search field.
   private var controls: some View {
      VStack(spacing: 10) {
         if rideMapViewModel.isIdle {
            circleButton(
               icon: .planRouteIcon,
               tint: rideMapViewModel.hasPlannedRoute ? PlannedRouteStyle.line : .white.opacity(0.75),
               label: "Plan a route",
               identifier: "map.button.planRoute",
               action: onPlanRoute
            )
         }

         cameraModeButton
      }
   }

   // MARK: - Heading

   /// Hidden entirely while the course is unknown: a placeholder bearing tells the
   /// rider nothing and the user annotation already shows which way they face.
   private func headingPill(degrees: String) -> some View {
      HStack(spacing: 6) {
         Text(rideMapViewModel.heading)
            .font(.footnote.weight(.bold))
            .kerning(0.5)

         Text(degrees)
            .font(.caption2.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.5))
      }
      .foregroundStyle(.white.opacity(0.9))
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(.black.opacity(0.7), in: .capsule)
      .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Heading")
      .accessibilityIdentifier("map.label.heading")
   }

   // MARK: - Camera Mode

   /// One control for both directions: hand off the camera to the rider, then
   /// give it back. A single 48pt circle is the whole cost of making the mode
   /// discoverable and reversible.
   private var cameraModeButton: some View {
      let isFollowing = rideMapViewModel.isFollowingRider

      return circleButton(
         icon: isFollowing ? .panIcon : .recenterIcon,
         tint: isFollowing ? .white.opacity(0.75) : .cyan,
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
            .frame(width: 48, height: 48)
            .background(.black.opacity(0.72), in: .circle)
            .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
            // The label sits over a live map, so the tap target has to be stated
            // rather than inferred from a mostly transparent glyph.
            .contentShape(.circle)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(label)
      .accessibilityIdentifier(identifier)
   }

   // MARK: - Readouts

   private var readouts: some View {
      HStack(spacing: 10) {
         RideMetricTile(
            title: "SPEED",
            value: rideMapViewModel.speed,
            unit: rideMapViewModel.speedUnit,
            identifier: "map.tile.speed"
         )

         RideMetricTile(
            title: "DISTANCE",
            value: rideMapViewModel.distance,
            unit: rideMapViewModel.distanceUnit,
            identifier: "map.tile.distance"
         )
      }
      .padding(6)
      .background(.black.opacity(0.72), in: .rect(cornerRadius: 22))
   }
}

// MARK: - Icons

private extension String {
   static let panIcon = "arrow.up.and.down.and.arrow.left.and.right"
   static let recenterIcon = "location.fill.viewfinder"
   static let planRouteIcon = "signpost.right.fill"
   static let destinationIcon = "flag.fill"
   static let clearRouteIcon = "xmark"
}

#Preview {
   ZStack(alignment: .bottom) {
      Color.gray
      RideMapOverlayView(
         rideMapViewModel: RideMapViewModel(),
         routeGuidanceViewModel: RouteGuidanceViewModel()
      ) {}
   }
   .preferredColorScheme(.dark)
}
