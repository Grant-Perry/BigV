//
//  RideMapDrawer.swift
//  BigV
//

import SwiftUI

/// Bottom-third live map on the dashboard. Default open, framed close, and
/// fully live: drag, pinch, rotate and tilt all work, and the camera returns to
/// the rider on its own a few seconds after they let go. The expand button — or
/// a double tap — opens the full map page. Swipe the grabber: up opens, down
/// collapses.
struct RideMapDrawer: View {

   /// Tall enough that the handle clears the control dock, which floats over
   /// the drawer's bottom edge. Any shorter and the only way back to the map is
   /// hidden under glass.
   static let collapsedHeight: CGFloat = 96
   static let openHeight: CGFloat = 190

   /// Drawer chrome is deliberately smaller than the map page's 48-point FABs:
   /// this map is 190 points tall, and furniture sized for a full screen covers
   /// the road it is drawn over.
   private static let chromeSize: CGFloat = 34

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
            .strokeBorder(RideDashboardTheme.ink(0.16), lineWidth: 1)
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
            .fill(RideDashboardTheme.ink(0.45))
            .frame(width: 36, height: 4)
      } else {
         Image(systemName: .showMapIcon)
            .font(.title3.weight(.semibold))
            .foregroundStyle(RideDashboardTheme.ink(0.55))
      }
   }

   // MARK: - Map

   private var mapBody: some View {
      ZStack(alignment: .topTrailing) {
         if isMapMounted {
            RideMapCanvasView(
               rideMapViewModel: rideMapViewModel,
               showsCompass: false,
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
   /// the view model the rider has taken the zoom over — and, on release, to
   /// start the countdown that hands the camera back.
   private var pinchToFreeZoom: some Gesture {
      MagnifyGesture(minimumScaleDelta: 0.01)
         .onChanged { _ in rideMapViewModel.riderTookOverDrawerZoom() }
         .onEnded { _ in rideMapViewModel.riderFinishedMovingCamera() }
   }

   // MARK: - Chrome

   /// Layered above the canvas so each button consumes its own hits.
   ///
   /// Parked at the top edge, opposite the control dock the dashboard floats
   /// over the bottom: between them the map keeps its whole middle, which is
   /// where the rider and the road ahead actually are.
   private var chrome: some View {
      HStack(spacing: 8) {
         expandButton
         recenterButton
      }
      .padding(.top, 8)
      .padding(.trailing, 10)
      .zIndex(1)
   }

   /// A visible way onto the full map. The double tap still works, but a drawer
   /// that pans needs a control the rider can see, not only a gesture they have
   /// to know about — and one that cannot be mistaken for a drag.
   private var expandButton: some View {
      chromeButton(
         icon: .expandIcon,
         tint: RideDashboardTheme.ink(0.85),
         label: "Open full map",
         identifier: "drawer.button.expand",
         action: onExpand
      )
   }

   private var recenterButton: some View {
      chromeButton(
         icon: .recenterIcon,
         tint: rideMapViewModel.isFollowingRider
            ? RideDashboardTheme.ink(0.85)
            : RideDashboardTheme.ice,
         label: "Center on my location",
         identifier: "drawer.button.recenter",
         action: rideMapViewModel.recenter
      )
   }

   private func chromeButton(
      icon: String,
      tint: Color,
      label: String,
      identifier: String,
      action: @escaping () -> Void
   ) -> some View {
      Button(action: action) {
         Image(systemName: icon)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: Self.chromeSize, height: Self.chromeSize)
            .contentShape(.circle)
      }
      .buttonStyle(.plain)
      .rideGlassChrome(in: Circle())
      .accessibilityLabel(label)
      .accessibilityIdentifier(identifier)
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
   static let expandIcon = "arrow.up.left.and.arrow.down.right"
}
