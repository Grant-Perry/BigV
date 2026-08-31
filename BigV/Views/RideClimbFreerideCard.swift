//
//  RideClimbFreerideCard.swift
//  BigV
//

import SwiftUI

/// The climb page without a route: honest about what it cannot know.
///
/// While the live detector says the rider is climbing, the card reports the
/// climb so far — ascent, distance, average grade. The rest of the time it
/// says plainly that forward-looking numbers need a route. It never guesses
/// how much climb is left, because nothing on freeride can know that.
struct RideClimbFreerideCard: View {

   let rideClimbModel: RideClimbModel

   var body: some View {
      if rideClimbModel.liveClimb.isClimbing {
         climbingCard
      } else {
         idleCard
      }
   }

   // MARK: - Climbing

   private var climbingCard: some View {
      VStack(spacing: 14) {
         HStack(spacing: 6) {
            Image(systemName: "arrow.up.right")
               .font(.caption.weight(.bold))
               .foregroundStyle(RideDashboardTheme.ember)

            Text("CLIMBING")
               .font(.caption2.weight(.bold))
               .kerning(1.2)
               .foregroundStyle(RideDashboardTheme.ember)

            Spacer()

            Text("SO FAR")
               .font(.system(size: 9, weight: .bold))
               .kerning(0.8)
               .foregroundStyle(.white.opacity(0.4))
         }

         HStack(spacing: 8) {
            figure("ASCENT", value: rideClimbModel.liveClimbAscentText)
            figure("DISTANCE", value: rideClimbModel.liveClimbDistanceText)
            figure("AVG GRADE", value: rideClimbModel.liveClimbGradeText)
         }
      }
      .padding(16)
      .rideGlassCard(density: .hud)
   }

   private func figure(_ label: String, value: String?) -> some View {
      VStack(spacing: 4) {
         Text(value ?? RideFormatters.placeholder)
            .font(.system(size: 22, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .minimumScaleFactor(0.6)
            .lineLimit(1)

         Text(label)
            .font(.system(size: 9, weight: .bold))
            .kerning(0.8)
            .foregroundStyle(.white.opacity(0.45))
      }
      .frame(maxWidth: .infinity)
   }

   // MARK: - Idle

   private var idleCard: some View {
      VStack(spacing: 10) {
         Image(systemName: "mountain.2")
            .font(.system(size: 34, weight: .light))
            .foregroundStyle(.white.opacity(0.25))

         Text("Need a route to see what's left")
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.7))

         Text("Plan a route or import a GPX and the profile ahead appears here. Climbs you ride are still detected and split automatically.")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.45))
            .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 24)
      .padding(.vertical, 28)
      .rideGlassCard(density: .hud)
   }
}
