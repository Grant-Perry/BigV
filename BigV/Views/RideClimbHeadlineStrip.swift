//
//  RideClimbHeadlineStrip.swift
//  BigV
//

import SwiftUI

/// The climb page's headline numbers, under the profile.
///
/// On a climb: to top, ascent left, average grade left, grade under the wheels
/// — the four the Edge taught riders to expect. Between climbs the strip turns
/// into the next-climb chip plus the route's remaining ascent, so the rider
/// always knows what they are saving their legs for.
struct RideClimbHeadlineStrip: View {

   let rideClimbModel: RideClimbModel

   var body: some View {
      if rideClimbModel.isOnClimb {
         activeClimbGrid
      } else {
         betweenClimbsRow
      }
   }

   // MARK: - On a Climb

   private var activeClimbGrid: some View {
      HStack(spacing: 8) {
         headline(
            "TO TOP",
            value: rideClimbModel.toTopComponents?.value ?? RideFormatters.placeholder,
            unit: rideClimbModel.toTopComponents?.unit
         )
         headline(
            "ASC LEFT",
            value: rideClimbModel.climbAscentRemainingText ?? RideFormatters.placeholder,
            unit: rideClimbModel.elevationUnit
         )
         headline(
            "AVG LEFT",
            value: rideClimbModel.remainingGradeText ?? RideFormatters.placeholder,
            unit: rideClimbModel.gradeUnit
         )
         headline(
            "GRADE",
            value: rideClimbModel.currentGradeText,
            unit: rideClimbModel.gradeUnit,
            tint: RideDashboardTheme.ember
         )
      }
   }

   private func headline(
      _ label: String,
      value: String,
      unit: String?,
      tint: Color = RideDashboardTheme.ink
   ) -> some View {
      VStack(spacing: 4) {
         HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
               .font(.system(size: 26, weight: .heavy, design: .rounded))
               .monospacedDigit()
               .foregroundStyle(tint)
               .minimumScaleFactor(0.6)
               .lineLimit(1)

            if let unit {
               Text(unit)
                  .font(.system(size: 10, weight: .semibold))
                  .foregroundStyle(RideDashboardTheme.ink(0.4))
            }
         }

         Text(label)
            .font(.system(size: 9, weight: .bold))
            .kerning(0.8)
            .foregroundStyle(RideDashboardTheme.ink(0.45))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .rideGlassCard(density: .hud)
   }

   // MARK: - Between Climbs

   @ViewBuilder
   private var betweenClimbsRow: some View {
      HStack(spacing: 8) {
         if let category = rideClimbModel.nextClimbCategoryLabel {
            nextClimbChip(category)
         } else {
            noMoreClimbsChip
         }

         headline(
            "ASC REMAINING",
            value: rideClimbModel.routeAscentRemainingText ?? RideFormatters.placeholder,
            unit: rideClimbModel.elevationUnit
         )
      }
   }

   /// "CAT 2 in 3.4 mi — +540 FT @ 5.4%": everything worth knowing about the
   /// next climb before it starts.
   private func nextClimbChip(_ category: String) -> some View {
      VStack(alignment: .leading, spacing: 4) {
         HStack(spacing: 6) {
            Text(category)
               .font(.caption2.weight(.bold))
               .kerning(0.6)
               .foregroundStyle(RideDashboardTheme.ember)
               .padding(.horizontal, 7)
               .padding(.vertical, 2)
               .background(RideDashboardTheme.ember.opacity(0.16), in: .capsule)

            Text(rideClimbModel.nextClimbDistanceText ?? "")
               .font(.system(size: 14, weight: .bold, design: .rounded))
               .monospacedDigit()
               .foregroundStyle(RideDashboardTheme.ink)
         }

         Text(rideClimbModel.nextClimbDemandText ?? "")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(RideDashboardTheme.ink(0.6))

         Text("NEXT CLIMB")
            .font(.system(size: 9, weight: .bold))
            .kerning(0.8)
            .foregroundStyle(RideDashboardTheme.ink(0.45))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .rideGlassCard(density: .hud)
   }

   private var noMoreClimbsChip: some View {
      VStack(alignment: .leading, spacing: 4) {
         Text("All climbs behind you")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(RideDashboardTheme.go)

         Text("NEXT CLIMB")
            .font(.system(size: 9, weight: .bold))
            .kerning(0.8)
            .foregroundStyle(RideDashboardTheme.ink(0.45))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .rideGlassCard(density: .hud)
   }
}
