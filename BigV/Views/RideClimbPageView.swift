//
//  RideClimbPageView.swift
//  BigV
//

import SwiftUI

/// The climb page: what the road ahead costs, at bar-mount reading distance.
///
/// Three faces, one layout. On a climb the chart windows that climb and four
/// headline numbers say what is left. Between climbs the whole route's profile
/// shows the day and a chip names the next climb. Freeride shows the climb
/// underway from telemetry alone and promises nothing it cannot know.
struct RideClimbPageView: View {

   @Environment(RideClimbModel.self) private var rideClimbModel

   var body: some View {
      VStack(spacing: 10) {
         header

         if let series = rideClimbModel.chartSeries {
            profileCard(series)
            RideClimbHeadlineStrip(rideClimbModel: rideClimbModel)
         } else {
            RideClimbFreerideCard(rideClimbModel: rideClimbModel)
         }

         Spacer(minLength: 0)

         dataStrip
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 6)
      .accessibilityIdentifier("ride.page.climb")
   }

   // MARK: - Header

   private var header: some View {
      HStack(spacing: 8) {
         Image(systemName: "mountain.2.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(
               rideClimbModel.isOnClimb ? RideDashboardTheme.ember : RideDashboardTheme.ink(0.4)
            )

         Text("CLIMB")
            .font(.caption2.weight(.bold))
            .kerning(1.2)
            .foregroundStyle(RideDashboardTheme.ink(0.7))

         Spacer()

         if let category = rideClimbModel.activeClimbCategoryLabel {
            categoryBadge(category)
         } else {
            Text(rideClimbModel.hasRouteData ? "ROUTE PROFILE" : "FREERIDE")
               .font(.caption2.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ink(0.45))
         }
      }
      .padding(.horizontal, 4)
   }

   private func categoryBadge(_ label: String) -> some View {
      Text(label)
         .font(.caption2.weight(.bold))
         .kerning(0.8)
         .foregroundStyle(RideDashboardTheme.ember)
         .padding(.horizontal, 8)
         .padding(.vertical, 3)
         .background(RideDashboardTheme.ember.opacity(0.16), in: .capsule)
   }

   // MARK: - Profile

   private func profileCard(_ series: RideClimbProfileSeries) -> some View {
      VStack(spacing: 6) {
         RideClimbProfileChart(
            series: series,
            climbSpans: rideClimbModel.chartClimbSpans,
            height: 235
         )

         HStack {
            Text(rideClimbModel.chartDistanceUnit)
               .font(.system(size: 8, weight: .bold))
               .kerning(0.8)
               .foregroundStyle(RideDashboardTheme.ink(0.3))

            Spacer()

            // The profile is Open-Meteo's work, credited where it shows.
            Text("ELEVATION © OPEN-METEO")
               .font(.system(size: 8, weight: .semibold))
               .kerning(0.6)
               .foregroundStyle(RideDashboardTheme.ink(0.25))
         }
      }
      .padding(12)
      .rideGlassCard(density: .hud)
   }

   // MARK: - Data Strip

   /// The always-true numbers: climbing rate, altitude, meters banked. Present
   /// on every face so the page is never empty-handed.
   private var dataStrip: some View {
      HStack(spacing: 0) {
         metric("VAM", value: rideClimbModel.vamText, unit: rideClimbModel.vamUnit)
         divider
         metric("ALTITUDE", value: rideClimbModel.altitudeText, unit: rideClimbModel.elevationUnit)
         divider
         metric("GAINED", value: rideClimbModel.elevationGainedText, unit: rideClimbModel.elevationUnit)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .rideGlassCard(density: .hud)
      .accessibilityElement(children: .combine)
   }

   private func metric(_ label: String, value: String, unit: String) -> some View {
      VStack(spacing: 3) {
         HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
               .font(.system(size: 20, weight: .bold, design: .rounded))
               .monospacedDigit()
               .foregroundStyle(RideDashboardTheme.ink)

            Text(unit)
               .font(.system(size: 10, weight: .semibold))
               .foregroundStyle(RideDashboardTheme.ink(0.4))
         }

         Text(label)
            .font(.system(size: 9, weight: .bold))
            .kerning(0.8)
            .foregroundStyle(RideDashboardTheme.ink(0.45))
      }
      .frame(maxWidth: .infinity)
   }

   private var divider: some View {
      Rectangle()
         .fill(RideDashboardTheme.ink(0.10))
         .frame(width: 1, height: 30)
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      RideClimbPageView()
   }
   .environment(RideClimbModel())
   .preferredColorScheme(.dark)
}
