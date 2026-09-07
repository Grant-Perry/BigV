//
//  RideRouteMapLegend.swift
//  BigV
//

import SwiftUI

/// Names the marks a route map draws, so nobody has to guess which one is
/// the finish and which one is a car.
///
/// Overlaid on the hero and detail maps. Pass entries appear only for the
/// tiers that ride actually plotted, so a radar-less map stays quiet.
struct RideRouteMapLegend: View {

   var radarPasses: [RideRadarPassAnnotation] = []

   var body: some View {
      HStack(spacing: 10) {
         entry(.start, label: "Start")
         entry(.finish, label: "Finish")

         if showsOrdinaryPasses {
            entry(.vehiclePass, label: "Pass")
         }

         if showsFastPasses {
            entry(.fastPass, label: "Fast")
         }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(RideDashboardTheme.veil(0.55), in: .capsule)
      .overlay {
         Capsule()
            .strokeBorder(RideDashboardTheme.ink(0.12), lineWidth: 0.5)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(accessibilityText)
   }

   // MARK: - Entries

   private var showsOrdinaryPasses: Bool {
      radarPasses.contains { $0.tier == .approaching }
   }

   private var showsFastPasses: Bool {
      radarPasses.contains { $0.tier == .high }
   }

   private func entry(_ kind: RideRouteMapMark.Kind, label: String) -> some View {
      HStack(spacing: 4) {
         RideRouteMapMark(kind: kind, role: .legend)

         Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(RideDashboardTheme.ink(0.75))
      }
   }

   private var accessibilityText: String {
      var parts = ["green start", "checkered finish"]
      if showsOrdinaryPasses { parts.append("amber vehicle passes") }
      if showsFastPasses { parts.append("red diamond fast approaches") }
      return "Map legend: " + parts.joined(separator: ", ")
   }
}

#Preview {
   ZStack {
      Color.black
      VStack(spacing: 12) {
         RideRouteMapLegend()
         RideRouteMapLegend(
            radarPasses: [
               RideRadarPassAnnotation(id: 0, latitude: 0, longitude: 0, tier: .approaching)
            ]
         )
         RideRouteMapLegend(
            radarPasses: [
               RideRadarPassAnnotation(id: 0, latitude: 0, longitude: 0, tier: .approaching),
               RideRadarPassAnnotation(id: 1, latitude: 0, longitude: 0, tier: .high)
            ]
         )
      }
   }
   .preferredColorScheme(.dark)
}
