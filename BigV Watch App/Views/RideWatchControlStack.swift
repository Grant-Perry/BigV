//
//  RideWatchControlStack.swift
//  BigV Watch App
//

import SwiftUI

/// Compact remote. Two actions sit side by side so they stop eating the glance.
struct RideWatchControlStack: View {

   let controls: [RideWatchControl]
   let onSend: (RideRemoteCommand) -> Void

   var body: some View {
      let pairing = controls.count > 1

      HStack(spacing: 6) {
         ForEach(controls) { control in
            Button {
               onSend(control.command)
            } label: {
               Text(control.title)
                  .font(.system(size: 11, weight: .bold))
                  .kerning(0.5)
                  .frame(maxWidth: .infinity)
                  .frame(height: pairing ? 26 : 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(tint(for: control.role), in: Capsule())
            .accessibilityIdentifier("watch.button.\(control.command.rawValue)")
         }
      }
   }

   // MARK: - Tint

   private func tint(for role: RideWatchControlRole) -> Color {
      switch role {
         case .go: RideChromeTokens.go
         case .hold: RideChromeTokens.ember
         case .stop: RideChromeTokens.halt
      }
   }
}

#Preview {
   VStack(spacing: 12) {
      RideWatchControlStack(
         controls: [
            RideWatchControl(command: .pause, title: "PAUSE", role: .hold),
            RideWatchControl(command: .end, title: "END", role: .stop)
         ],
         onSend: { _ in }
      )

      RideWatchControlStack(
         controls: [
            RideWatchControl(command: .start, title: "START", role: .go)
         ],
         onSend: { _ in }
      )
   }
   .padding()
   .background(RideChromeTokens.void)
}
