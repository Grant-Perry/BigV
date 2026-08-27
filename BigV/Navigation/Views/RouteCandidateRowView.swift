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

   var body: some View {
      VStack(alignment: .leading, spacing: 6) {
         header

         if !advisories.isEmpty {
            advisoryList
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(wash, in: .rect(cornerRadius: 16))
      .overlay(
         RoundedRectangle(cornerRadius: 16)
            .stroke(isSelected ? PlannedRouteStyle.line : .white.opacity(0.10), lineWidth: 2)
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

   // MARK: - Wash

   private var wash: LinearGradient {
      let intensity = isSelected ? 0.18 : 0.10

      return LinearGradient(
         colors: [.white.opacity(intensity), .white.opacity(intensity / 3)],
         startPoint: .topLeading,
         endPoint: .bottomTrailing
      )
   }
}

// MARK: - Icons

private extension String {
   static let advisoryIcon = "exclamationmark.triangle.fill"
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
