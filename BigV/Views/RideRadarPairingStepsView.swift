//
//  RideRadarPairingStepsView.swift
//  BigV
//

import SwiftUI

/// How to put a Varia into pairing mode, shown before and during a scan.
///
/// Newer radars (RearVue 820) accept a new phone only while in pairing mode;
/// outside it they take the link and drop it a moment later, which looks like
/// a flaky radio. Saying this up front beats diagnosing it after the fact.
struct RideRadarPairingStepsView: View {

   private let steps: [String] = [
      "Turn the radar off.",
      "Hold its button about 2 seconds until the status light flashes. That is pairing mode.",
      "Keep your iPhone within arm’s reach, then tap Scan and choose the radar."
   ]

   var body: some View {
      VStack(alignment: .leading, spacing: 8) {
         Label("Put the radar in pairing mode first", systemImage: "link.badge.plus")
            .font(.caption.weight(.semibold))
            .foregroundStyle(RideDashboardTheme.ice)

         ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
            HStack(alignment: .firstTextBaseline, spacing: 8) {
               Text("\(index + 1)")
                  .font(.caption2.weight(.bold))
                  .foregroundStyle(RideDashboardTheme.ice)
                  .frame(width: 16, height: 16)
                  .background(RideDashboardTheme.ice.opacity(0.18), in: .circle)

               Text(step)
                  .font(.caption)
                  .foregroundStyle(RideDashboardTheme.ink(0.75))
                  .fixedSize(horizontal: false, vertical: true)
            }
         }

         Text("Older Varia models (RTL515, RTL510) pair whenever they are on. If a radar connects then drops again and again, it is not in pairing mode.")
            .font(.caption2)
            .foregroundStyle(RideDashboardTheme.ink(0.45))
            .fixedSize(horizontal: false, vertical: true)
      }
      .padding(12)
      .background(RideDashboardTheme.ink(0.06), in: .rect(cornerRadius: 10))
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("radar.pairingSteps")
   }
}

#Preview {
   RideRadarPairingStepsView()
      .padding()
      .background(.black)
}
