//
//  RoutePlanningFailureView.swift
//  BigV
//

import SwiftUI

/// Says plainly why there is no route.
///
/// "Apple has no bike route here" and "the request failed" get different words
/// because they need different reactions from the rider: pick somewhere else
/// versus try again.
struct RoutePlanningFailureView: View {

   let failure: RoutePlanningFailure

   var body: some View {
      VStack(alignment: .leading, spacing: 4) {
         Text(failure.title)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.orange)

         Text(failure.message)
            .font(.footnote)
            .foregroundStyle(RideDashboardTheme.ink(0.7))
            .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(Self.wash, in: .rect(cornerRadius: 16))
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("planner.label.failure")
   }

   private static let wash = LinearGradient(
      colors: [.orange.opacity(0.18), .orange.opacity(0.05)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
   )
}

#Preview {
   ZStack {
      Color.black.ignoresSafeArea()
      RoutePlanningFailureView(failure: .noCyclingRoute)
         .padding()
   }
   .preferredColorScheme(.dark)
}
