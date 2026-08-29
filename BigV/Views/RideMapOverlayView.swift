//
//  RideMapOverlayView.swift
//  BigV
//

import SwiftUI

/// Live numbers, heading and map chrome layered over the ride map.
///
/// Speed and distance sit at the top, under the destination chip, so they never
/// fight the legal attribution or the FABs.
struct RideMapOverlayView: View {

   let rideMapViewModel: RideMapViewModel
   let routeGuidanceViewModel: RouteGuidanceViewModel

   var body: some View {
      VStack(spacing: 10) {
         if routeGuidanceViewModel.isActive {
            RouteGuidanceBannerView(
               routeGuidanceViewModel: routeGuidanceViewModel,
               rideMapViewModel: rideMapViewModel
            )
         }

         topRow
         readouts

         Spacer(minLength: 0)
            .allowsHitTesting(false)

         HStack {
            Spacer(minLength: 0)
               .allowsHitTesting(false)

            RideMapFABStack(rideMapViewModel: rideMapViewModel)
               .padding(.trailing, 8)
         }
      }
      .padding(.horizontal, 16)
      .safeAreaPadding(.top, 8)
      .safeAreaPadding(.trailing, 16)
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
            .foregroundStyle(RideDashboardTheme.ember)

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
      .rideGlassChrome(in: .capsule)
      .frame(maxWidth: 210, alignment: .trailing)
      .accessibilityIdentifier("map.label.destination")
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
      .rideGlassChrome(in: .capsule)
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Heading")
      .accessibilityIdentifier("map.label.heading")
   }

   // MARK: - Readouts

   private var readouts: some View {
      HStack(spacing: 10) {
         RideMetricTile(
            title: "SPEED",
            value: rideMapViewModel.speed,
            unit: rideMapViewModel.speedUnit,
            identifier: "map.tile.speed",
            gutterAlignment: .trailing
         )

         RideMetricTile(
            title: "DISTANCE",
            value: rideMapViewModel.distance,
            unit: rideMapViewModel.distanceUnit,
            identifier: "map.tile.distance",
            gutterAlignment: .leading
         )
      }
   }
}

// MARK: - Icons

private extension String {
   static let destinationIcon = "flag.fill"
   static let clearRouteIcon = "xmark"
}

#Preview {
   ZStack {
      Color.gray
      RideMapOverlayView(
         rideMapViewModel: RideMapViewModel(),
         routeGuidanceViewModel: RouteGuidanceViewModel()
      )
   }
   .preferredColorScheme(.dark)
}
