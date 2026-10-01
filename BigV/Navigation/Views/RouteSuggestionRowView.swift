//
//  RouteSuggestionRowView.swift
//  BigV
//

import SwiftUI

/// One search completion: the place, and the line that tells two of them apart.
struct RouteSuggestionRowView: View {

   let suggestion: RouteSearchSuggestion

   var body: some View {
      VStack(alignment: .leading, spacing: 2) {
         Text(suggestion.title)
            .font(.body.weight(.semibold))
            .foregroundStyle(RideDashboardTheme.ink)

         if suggestion.hasSubtitle {
            Text(suggestion.subtitle)
               .font(.caption)
               .foregroundStyle(RideDashboardTheme.ink(0.5))
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 6)
      .contentShape(.rect)
   }
}
