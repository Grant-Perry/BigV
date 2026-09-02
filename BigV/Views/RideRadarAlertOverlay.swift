//
//  RideRadarAlertOverlay.swift
//  BigV
//

import SwiftUI

/// A brief screen-edge tint when a threat enters or escalates — amber then
/// red, following the Edge's colour-overlay behaviour — and a green wash for
/// the all-clear, the only moment green is allowed to mean anything.
///
/// Purely decorative: never intercepts touches, defeatable in radar settings,
/// and under Reduce Motion the tint appears and clears without animation.
struct RideRadarAlertOverlay: View {

   let tier: RideRadarThreatTier?
   let alertPulse: Int
   let clearPulse: Int
   let isEnabled: Bool

   @Environment(\.accessibilityReduceMotion) private var reduceMotion

   @State private var flashColor: Color = .clear
   @State private var flashOpacity: Double = 0
   @State private var fadeTask: Task<Void, Never>?

   var body: some View {
      Rectangle()
         .strokeBorder(flashColor, lineWidth: 42)
         .blur(radius: 34)
         .opacity(flashOpacity)
         .ignoresSafeArea()
         .allowsHitTesting(false)
         .accessibilityHidden(true)
         .onChange(of: alertPulse) { _, _ in
            guard isEnabled else { return }
            flash(color: tierColor, holdFor: 0.9)
         }
         .onChange(of: clearPulse) { _, _ in
            guard isEnabled else { return }
            flash(color: RideDashboardTheme.go, holdFor: 0.6)
         }
   }

   private var tierColor: Color {
      switch tier {
         case .high: RideDashboardTheme.halt
         case .approaching, nil: RideDashboardTheme.amber
      }
   }

   /// Snaps the tint on, holds it a beat, and fades it out. Each new pulse
   /// restarts the sequence so a burst of traffic reads as one live signal.
   private func flash(color: Color, holdFor hold: TimeInterval) {
      fadeTask?.cancel()

      flashColor = color
      flashOpacity = 0.85

      fadeTask = Task {
         try? await Task.sleep(for: .seconds(hold))
         guard !Task.isCancelled else { return }

         if reduceMotion {
            flashOpacity = 0
         } else {
            withAnimation(.easeOut(duration: 0.7)) {
               flashOpacity = 0
            }
         }
      }
   }
}
