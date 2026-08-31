//
//  RouteClimbListView.swift
//  BigV
//

import SwiftUI

/// The selected candidate's climbs, one compact row each, expandable to a
/// grade-coloured mini profile.
///
/// Lives under the candidate list on the preview stage so the rider weighs the
/// climbs the same moment they weigh the distance — that comparison is the
/// whole reason the alternates exist.
struct RouteClimbListView: View {

   let route: PlannedRoute

   @State private var expandedClimbID: Int?

   var body: some View {
      VStack(spacing: 6) {
         ForEach(route.climbs) { climb in
            climbRow(climb)
         }
      }
   }

   // MARK: - Row

   private func climbRow(_ climb: PlannedClimb) -> some View {
      Button {
         withAnimation(.smooth(duration: 0.25)) {
            expandedClimbID = expandedClimbID == climb.id ? nil : climb.id
         }
      } label: {
         VStack(spacing: 8) {
            rowHeader(climb)

            if expandedClimbID == climb.id {
               miniProfile(climb)
            }
         }
         .padding(.horizontal, 12)
         .padding(.vertical, 9)
         .rideGlassCard(density: .hud, cornerRadius: 12)
         .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("planner.climb.\(climb.id)")
   }

   private func rowHeader(_ climb: PlannedClimb) -> some View {
      HStack(spacing: 8) {
         Text(climb.category.label)
            .font(.system(size: 10, weight: .bold))
            .kerning(0.6)
            .foregroundStyle(RideDashboardTheme.ember)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(RideDashboardTheme.ember.opacity(0.14), in: .capsule)

         Text("\(PlannedRouteFormatters.climbLength(climb.length)) @ \(PlannedRouteFormatters.averageGrade(climb.averageGrade))")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.75))

         Spacer()

         Text(PlannedRouteFormatters.elevationGain(climb.ascent))
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(.white)

         Image(systemName: "chevron.down")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white.opacity(0.35))
            .rotationEffect(.degrees(expandedClimbID == climb.id ? 180 : 0))
      }
   }

   // MARK: - Mini Profile

   /// The climb alone, base to crest, same grade ramp as the live page — the
   /// preview teaches the colours the ride will use.
   @ViewBuilder
   private func miniProfile(_ climb: PlannedClimb) -> some View {
      if let series = RideClimbProfileSeriesBuilder.series(
         profile: route.elevationProfile,
         start: climb.startDistance,
         end: climb.endDistance,
         playheadDistance: nil,
         playheadAltitude: nil,
         system: .current
      ) {
         RideClimbProfileChart(series: series, climbSpans: [], height: 88)
      }
   }
}
