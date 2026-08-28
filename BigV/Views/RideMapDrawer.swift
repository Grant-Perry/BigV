//
//  RideMapDrawer.swift
//  BigV
//

import SwiftUI

/// Bottom-third live map on the dashboard. Default open. Tap expands to the
/// full map page. Swipe the grabber: up opens, down collapses.
struct RideMapDrawer: View {

   static let collapsedHeight: CGFloat = 72
   static let openHeight: CGFloat = 220
   static let controlClearance: CGFloat = 62

   let rideMapViewModel: RideMapViewModel
   var isMapMounted: Bool
   var isVertical: Bool = true
   let onExpand: () -> Void
   let onPlanRoute: () -> Void

   @Binding var isOpen: Bool

   var body: some View {
      VStack(spacing: 0) {
         grabber

         if isOpen {
            mapBody
         }
      }
      .frame(maxWidth: .infinity, maxHeight: isVertical && !isOpen ? Self.collapsedHeight : .infinity)
      .frame(height: isVertical ? (isOpen ? Self.openHeight : Self.collapsedHeight) : nil)
      .clipShape(.rect(cornerRadius: 18, style: .continuous))
      .overlay {
         RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
      }
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("ride.drawer.map")
   }

   // MARK: - Grabber

   private var grabber: some View {
      VStack(spacing: 4) {
         Capsule()
            .fill(.white.opacity(0.45))
            .frame(width: 36, height: 4)

         if !isOpen {
            Color.clear
               .frame(height: 44)
         }
      }
      .frame(maxWidth: .infinity)
      .padding(.top, 8)
      .padding(.bottom, isOpen ? 6 : 8)
      .contentShape(.rect)
      .gesture(drawerDrag)
      .onTapGesture {
         if isOpen {
            onExpand()
         } else {
            isOpen = true
         }
      }
      .accessibilityLabel(isOpen ? "Map drawer, open" : "Map drawer, collapsed")
      .accessibilityHint(isOpen ? "Double tap to open the full map" : "Double tap to open the map drawer")
      .accessibilityAddTraits(.isButton)
   }

   // MARK: - Map

   private var mapBody: some View {
      ZStack(alignment: .bottomTrailing) {
         if isMapMounted {
            RideMapCanvasView(
               rideMapViewModel: rideMapViewModel,
               showsCompass: false,
               allowsInteraction: false
            )
         } else {
            RideDashboardTheme.graphite
         }

         Color.clear
            .contentShape(.rect)
            .simultaneousGesture(TapGesture().onEnded(onExpand))
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Ride map")
            .accessibilityHint("Opens the full map")

         chrome
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
   }

   // MARK: - Chrome

   /// Overlay on top of the expand tap layer so the FABs consume their own hits.
   private var chrome: some View {
      GlassEffectContainer(spacing: 10) {
         VStack(spacing: 10) {
            RideSearchButton(
               style: .fab,
               identifier: "drawer.button.search",
               action: onPlanRoute
            )

            recenterButton
         }
      }
      .padding(.trailing, 12)
      .padding(.bottom, Self.controlClearance)
      .zIndex(1)
   }

   private var recenterButton: some View {
      Button(action: rideMapViewModel.recenter) {
         Image(systemName: .recenterIcon)
            .font(.body.weight(.semibold))
            .foregroundStyle(
               rideMapViewModel.isFollowingRider
                  ? .white.opacity(0.85)
                  : RideDashboardTheme.ice
            )
            .frame(width: RideDashboardTheme.fabSize, height: RideDashboardTheme.fabSize)
            .contentShape(.circle)
      }
      .buttonStyle(.plain)
      .rideGlassChrome(in: Circle())
      .accessibilityLabel("Center on my location")
      .accessibilityIdentifier("drawer.button.recenter")
   }

   // MARK: - Drag

   private var drawerDrag: some Gesture {
      DragGesture(minimumDistance: 16)
         .onEnded { value in
            if value.translation.height < -32 {
               isOpen = true
            } else if value.translation.height > 32 {
               isOpen = false
            }
         }
   }
}

private extension String {
   static let recenterIcon = "location.fill.viewfinder"
}
