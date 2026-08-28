//
//  RideWatchControlStack.swift
//  BigV Watch App
//

import SwiftUI

/// The remote. Whatever the phone's phase allows, sized for a gloved tap.
struct RideWatchControlStack: View {

   let controls: [RideWatchControl]
   let onSend: (RideRemoteCommand) -> Void

   var body: some View {
      VStack(spacing: 6) {
         ForEach(controls) { control in
            Button {
               onSend(control.command)
            } label: {
               Text(control.title)
                  .font(.footnote.weight(.bold))
                  .kerning(0.8)
                  .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(tint(for: control.role))
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
   RideWatchControlStack(
      controls: [
         RideWatchControl(command: .pause, title: "PAUSE", role: .hold),
         RideWatchControl(command: .end, title: "END", role: .stop)
      ],
      onSend: { _ in }
   )
   .padding()
   .background(RideChromeTokens.void)
}
