//
//  RouteSectionHeaderButton.swift
//  BigV
//

import SwiftUI

/// The collapsible header shared by the planner's Favorites and Recents
/// sections: title, count, an optional trailing action, and the star-boom
/// chevron that marks every disclosure in the app.
struct RouteSectionHeaderButton: View {

   let title: String
   let count: Int
   @Binding var isExpanded: Bool
   var trailingActionTitle: String?
   var trailingAction: (() -> Void)?
   let identifier: String

   @State private var boomTrigger = 0

   var body: some View {
      HStack(spacing: 8) {
         Button {
            boomTrigger += 1
            withAnimation(.easeInOut(duration: 0.2)) {
               isExpanded.toggle()
            }
         } label: {
            HStack(spacing: 8) {
               Text(title)
                  .font(.subheadline.weight(.bold))
                  .foregroundStyle(RideDashboardTheme.ink(0.85))

               Text("\(count)")
                  .font(.caption.weight(.semibold))
                  .monospacedDigit()
                  .foregroundStyle(RideDashboardTheme.ink(0.45))

               Spacer(minLength: 0)

               StarBoomChevron(
                  isExpanded: isExpanded,
                  boomTrigger: boomTrigger,
                  foregroundColor: RideDashboardTheme.ink(0.55)
               )
            }
            .contentShape(.rect)
         }
         .buttonStyle(.plain)
         .accessibilityIdentifier(identifier)

         if isExpanded, let trailingActionTitle, let trailingAction {
            Button(trailingActionTitle, action: trailingAction)
               .font(.caption.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ember)
               .buttonStyle(.plain)
               .accessibilityIdentifier("\(identifier).action")
         }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .rideGlassCard(density: .hud)
   }
}
