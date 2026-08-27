//
//  RideControlBar.swift
//  BigV
//

import SwiftUI

/// Start, pause, resume and end, sized for gloved thumbs on a mounted phone.
struct RideControlBar: View {

   let rideViewModel: RideViewModel

   var body: some View {
      HStack(spacing: 10) {
         switch rideViewModel.phase {
            case .idle:
               control("START", tint: RideDashboardTheme.go, action: rideViewModel.start)

            case .acquiringGPS:
               control("ACQUIRING GPS", tint: .gray, isEnabled: false) {}
               control("CANCEL", tint: RideDashboardTheme.halt, action: rideViewModel.end)

            case .recording:
               control("PAUSE", tint: RideDashboardTheme.pause, action: rideViewModel.pause)
               control("END", tint: RideDashboardTheme.halt, action: rideViewModel.end)

            case .paused:
               control("RESUME", tint: RideDashboardTheme.go, action: rideViewModel.resume)
               control("END", tint: RideDashboardTheme.halt, action: rideViewModel.end)

            case .finished:
               control("NEW RIDE", tint: RideDashboardTheme.ice, action: rideViewModel.reset)
         }
      }
   }

   // MARK: - Control

   private func control(
      _ title: String,
      tint: Color,
      isEnabled: Bool = true,
      action: @escaping () -> Void
   ) -> some View {
      Button(action: action) {
         Text(title)
            .font(.subheadline.weight(.bold))
            .kerning(1)
            .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.extraLarge)
      .tint(tint)
      .disabled(!isEnabled)
   }
}

#Preview {
   ZStack {
      Color.black
      RideControlBar(rideViewModel: RideViewModel())
         .padding()
   }
}
