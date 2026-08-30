//
//  RideMapDrawer.swift
//  BigV
//

import SwiftUI

/// Bottom-third live map on the dashboard. Default open, framed close, and
/// live: pinch, rotate and tilt all work. A double tap expands to the full map
/// page. Swipe the grabber: up opens, down collapses.
struct RideMapDrawer: View {

   /// Tall enough that the handle clears the control dock, which floats over
   /// the drawer's bottom edge. Any shorter and the only way back to the map is
   /// hidden under glass.
   static let collapsedHeight: CGFloat = 96
   static let openHeight: CGFloat = 190
   static let controlClearance: CGFloat = 62

   let rideMapViewModel: RideMapViewModel
   var isMapMounted: Bool
   var isVertical: Bool = true
   let onExpand: () -> Void

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
         handleGlyph

         // Collapsed, the whole strip is the handle: the control dock covers
         // its middle, so a hit area the size of the capsule alone leaves the
         // rider with nothing to press.
         if !isOpen {
            Spacer(minLength: 0)
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

   /// A chevron once collapsed: a bare capsule reads as decoration when there
   /// is no map under it to pull down.
   @ViewBuilder
   private var handleGlyph: some View {
      if isOpen {
         Capsule()
            .fill(.white.opacity(0.45))
            .frame(width: 36, height: 4)
      } else {
         Image(systemName: .showMapIcon)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white.opacity(0.55))
      }
   }

   // MARK: - Map

   private var mapBody: some View {
      ZStack(alignment: .bottomTrailing) {
         if isMapMounted {
            RideMapCanvasView(
               rideMapViewModel: rideMapViewModel,
               showsCompass: false,
               interactionModes: RideMapViewModel.drawerInteractionModes,
               cameraBounds: rideMapViewModel.drawerCameraBounds
            )
            // No full-bleed tap catcher: it would swallow the map's own
            // gestures. A double tap expands, single taps stay with the map.
            .highPriorityGesture(TapGesture(count: 2).onEnded(onExpand))
            .simultaneousGesture(pinchToFreeZoom)
            .accessibilityLabel("Ride map")
            .accessibilityAction(named: "Open full map", onExpand)
         } else {
            RideDashboardTheme.graphite
         }

         chrome
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
   }

   /// Rides alongside MapKit's pinch rather than replacing it, purely to tell
   /// the view model the rider has taken the zoom over.
   private var pinchToFreeZoom: some Gesture {
      MagnifyGesture(minimumScaleDelta: 0.01)
         .onChanged { _ in rideMapViewModel.riderTookOverDrawerZoom() }
   }

   // MARK: - Chrome

   /// Layered above the canvas so the FAB consumes its own hits.
   /// Recentring only: address search is a tab now, not map furniture.
   private var chrome: some View {
      recenterButton
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
   static let showMapIcon = "chevron.compact.up"
}
