//
//  RouteCandidateRowView.swift
//  BigV
//

import SwiftUI

/// One candidate route: what it is, how far, how long, and anything Apple wants
/// the rider warned about.
struct RouteCandidateRowView: View {

   let title: String
   let detail: String?
   let distanceText: String
   let travelTimeText: String
   let advisories: [String]
   let isSelected: Bool
   var climbSummary: String?
   var isLoadingElevation = false

   var body: some View {
      VStack(alignment: .leading, spacing: 6) {
         header

         if climbSummary != nil || isLoadingElevation {
            climbLine
         }

         if !advisories.isEmpty {
            advisoryList
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .rideGlassCard(density: isSelected ? .standard : .hud)
      .overlay(
         RoundedRectangle(cornerRadius: RideDashboardTheme.cardRadius, style: .continuous)
            .stroke(isSelected ? RideDashboardTheme.ember : .white.opacity(0.10), lineWidth: 2)
      )
      .contentShape(.rect)
      .accessibilityElement(children: .combine)
      .accessibilityAddTraits(isSelected ? .isSelected : [])
   }

   // MARK: - Header

   private var header: some View {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
         VStack(alignment: .leading, spacing: 2) {
            Text(title)
               .font(.subheadline.weight(.bold))
               .foregroundStyle(isSelected ? PlannedRouteStyle.line : .white.opacity(0.85))

            if let detail {
               Text(detail)
                  .font(.caption)
                  .foregroundStyle(.white.opacity(0.45))
                  .lineLimit(1)
            }
         }

         Spacer(minLength: 8)

         VStack(alignment: .trailing, spacing: 2) {
            Text(travelTimeText)
               .font(.title3.weight(.semibold))
               .monospacedDigit()
               .foregroundStyle(.white)

            Text(distanceText)
               .font(.caption.weight(.medium))
               .monospacedDigit()
               .foregroundStyle(.white.opacity(0.55))
         }
      }
   }

   // MARK: - Climbs

   /// The route's vertical story, or the loading whisper while Open-Meteo
   /// answers. Absent entirely when enrichment failed — no stuck spinners.
   @ViewBuilder
   private var climbLine: some View {
      if let climbSummary {
         HStack(spacing: 5) {
            Image(systemName: .climbIcon)
               .font(.caption2)
               .foregroundStyle(RideDashboardTheme.ember.opacity(0.85))

            Text(climbSummary)
               .font(.caption.weight(.medium))
               .monospacedDigit()
               .foregroundStyle(.white.opacity(0.65))
         }
      } else {
         Text("Loading elevation…")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.35))
      }
   }

   // MARK: - Advisories

   private var advisoryList: some View {
      VStack(alignment: .leading, spacing: 3) {
         ForEach(advisories, id: \.self) { advisory in
            HStack(alignment: .top, spacing: 5) {
               Image(systemName: .advisoryIcon)
                  .font(.caption2)

               Text(advisory)
                  .font(.caption2)
                  .fixedSize(horizontal: false, vertical: true)
            }
         }
      }
      .foregroundStyle(.yellow.opacity(0.8))
   }

}

// MARK: - Icons

private extension String {
   static let advisoryIcon = "exclamationmark.triangle.fill"
   static let climbIcon = "mountain.2.fill"
}

#Preview {
   ZStack {
      Color.black.ignoresSafeArea()
      VStack(spacing: 8) {
         RouteCandidateRowView(
            title: "Recommended",
            detail: "via Sand Hill Road",
            distanceText: "8.42 MI",
            travelTimeText: "42 min",
            advisories: ["Bike path closed after dark"],
            isSelected: true
         )

         RouteCandidateRowView(
            title: "Alternate 1",
            detail: nil,
            distanceText: "9.10 MI",
            travelTimeText: "46 min",
            advisories: [],
            isSelected: false
         )
      }
      .padding()
   }
   .preferredColorScheme(.dark)
}
