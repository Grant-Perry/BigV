//
//  RideRouteMapLegend.swift
//  BigV
//

import SwiftUI

/// Names the dots a route map draws, so nobody has to guess which one is the
/// finish and which one is a car.
///
/// Overlaid on the hero and detail maps. The vehicle entry appears only when
/// the ride actually recorded radar passes, so a radar-less map stays quiet.
struct RideRouteMapLegend: View {

   var showsVehicles = false

   var body: some View {
      HStack(spacing: 10) {
         entry(.green, label: "Start")
         entry(.red, label: "Finish")

         if showsVehicles {
            entry(RideChromeTokens.amber, label: "Vehicle")
         }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(.black.opacity(0.55), in: .capsule)
      .overlay {
         Capsule()
            .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(
         showsVehicles
            ? "Map legend: green start, red finish, amber vehicle passes"
            : "Map legend: green start, red finish"
      )
   }

   private func entry(_ color: Color, label: String) -> some View {
      HStack(spacing: 4) {
         Circle()
            .fill(color)
            .frame(width: 6, height: 6)

         Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.75))
      }
   }
}

#Preview {
   ZStack {
      Color.black
      VStack(spacing: 12) {
         RideRouteMapLegend()
         RideRouteMapLegend(showsVehicles: true)
      }
   }
   .preferredColorScheme(.dark)
}
