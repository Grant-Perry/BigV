//
//  RideWatchControlStack.swift
//  BigV Watch App
//

import SwiftUI

/// The remote: transport glyphs, centred, never more than two.
///
/// Icon-only and round because this bar is pinned below the glance rather than
/// scrolled with it. Every point it does not take is a point the numbers get.
struct RideWatchControlStack: View {

   let controls: [RideWatchControl]
   let onSend: (RideRemoteCommand) -> Void

   /// One size for every control, whether it stands alone or in a pair.
   private static let diameter: CGFloat = 40

   var body: some View {
      HStack(spacing: 16) {
         ForEach(controls) { control in
            Button {
               onSend(control.command)
            } label: {
               Image(systemName: control.glyph.rawValue)
                  .font(.system(size: 15, weight: .heavy))
                  .frame(width: Self.diameter, height: Self.diameter)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(tint(for: control.role), in: .circle)
            .accessibilityLabel(control.title)
            .accessibilityIdentifier("watch.button.\(control.command.rawValue)")
         }
      }
      .frame(maxWidth: .infinity)
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
            RideWatchControl(command: .pause, title: "Pause", glyph: .pause, role: .hold),
            RideWatchControl(command: .end, title: "End ride", glyph: .stop, role: .stop)
         ],
         onSend: { _ in }
      )

      RideWatchControlStack(
         controls: [
            RideWatchControl(command: .start, title: "Start ride", glyph: .play, role: .go)
         ],
         onSend: { _ in }
      )
   }
   .padding()
   .background(RideChromeTokens.void)
}
