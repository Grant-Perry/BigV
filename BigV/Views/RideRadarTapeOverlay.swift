//
//  RideRadarTapeOverlay.swift
//  BigV
//

import SwiftUI

/// Lays the radar tape over a surface without taking any of its space.
///
/// An overlay rather than a reserved gutter on purpose: the cockpit is sized
/// for the numbers a rider stares at, and the tape is glanced at. Reflowing the
/// speed hero and the tiles every time a radar connected cost more than it was
/// worth, and it squeezed the status chips into ellipses.
///
/// Never hit-testable — the tiles and buttons underneath keep every tap.
struct RideRadarTapeOverlay: ViewModifier {

   let placement: RideRadarPlacement
   let tracks: [RideRadarTracker.Track]
   let isVisible: Bool
   var isDimmed = false
   var unitSystem: RideUnitSystem = .current

   /// Cross-axis size of the tape. Defaults to the cockpit scale.
   var thickness: CGFloat?

   /// Cap on the tape's long axis, for surfaces with furniture at both ends.
   /// Unset runs the full length of the host.
   var length: CGFloat?

   /// Clearance at the two ends of the tape, so it never butts the corners.
   var inset: CGFloat = 2

   /// Clearance between the tape and the edge it is parked on.
   var edgeInset: CGFloat = 0

   /// Parks the tape somewhere other than its placement's natural edge, for
   /// hosts whose natural edge lands on live numbers. The tape still reads the
   /// same way — only where it sits changes.
   var alignment: Alignment?
   var edge: Edge.Set?

   func body(content: Content) -> some View {
      content
         .overlay(alignment: alignment ?? placement.overlayAlignment) {
            if isVisible {
               tape
                  .transition(.move(edge: placement.transitionEdge).combined(with: .opacity))
            }
         }
         .animation(.smooth(duration: 0.3), value: isVisible)
         .animation(.smooth(duration: 0.3), value: placement)
   }

   private var tape: some View {
      RideRadarTapeView(
         tracks: tracks,
         isDimmed: isDimmed,
         unitSystem: unitSystem,
         placement: placement,
         thickness: thickness ?? placement.cockpitThickness
      )
      .frame(
         maxWidth: placement.isVertical ? nil : length,
         maxHeight: placement.isVertical ? length : nil
      )
      .padding(placement.isVertical ? .vertical : .horizontal, inset)
      .padding(edge ?? placement.overlayEdge, edgeInset)
      .allowsHitTesting(false)
   }
}

extension View {

   /// Overlays the rear-radar tape on the edge the rider parked it on.
   func rideRadarTape(
      placement: RideRadarPlacement,
      tracks: [RideRadarTracker.Track],
      isVisible: Bool,
      isDimmed: Bool = false,
      unitSystem: RideUnitSystem = .current,
      thickness: CGFloat? = nil,
      length: CGFloat? = nil,
      inset: CGFloat = 2,
      edgeInset: CGFloat = 0,
      alignment: Alignment? = nil,
      edge: Edge.Set? = nil
   ) -> some View {
      modifier(
         RideRadarTapeOverlay(
            placement: placement,
            tracks: tracks,
            isVisible: isVisible,
            isDimmed: isDimmed,
            unitSystem: unitSystem,
            thickness: thickness,
            length: length,
            inset: inset,
            edgeInset: edgeInset,
            alignment: alignment,
            edge: edge
         )
      )
   }
}
