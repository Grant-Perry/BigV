//
//  RideClimbModel+Presentation.swift
//  BigV
//

import Foundation

/// Every string the climb page and its tiles show, so the views stay dumb and
/// the tile and the page can never format the same meters two ways.
extension RideClimbModel {

   // MARK: - Availability

   /// Whether forward-looking numbers exist at all.
   var hasRouteData: Bool { progress.hasRouteProfile }

   var isOnClimb: Bool { progress.activeClimb != nil }

   // MARK: - Units

   var elevationUnit: String { unitSystem.elevationUnit }
   var gradeUnit: String { RideFormatters.Unit.grade }
   var vamUnit: String { "M/H" }

   // MARK: - Live Readings

   var currentGradeText: String {
      state.hasGPSFix ? RideFormatters.grade(state.grade) : RideFormatters.placeholder
   }

   var vamText: String {
      state.hasGPSFix ? RideFormatters.verticalSpeed(state.verticalSpeed) : RideFormatters.placeholder
   }

   var altitudeText: String {
      guard let altitude = state.altitude else { return RideFormatters.placeholder }
      return RideFormatters.elevation(altitude, system: unitSystem)
   }

   var elevationGainedText: String {
      RideFormatters.elevation(state.elevationGain, system: unitSystem)
   }

   // MARK: - This Climb

   var activeClimbCategoryLabel: String? { progress.activeClimb?.category.label }

   /// "0.6" + "MI", adaptive like a turn distance.
   var toTopComponents: (value: String, unit: String)? {
      progress.distanceToTop.map {
         PlannedRouteFormatters.climbDistanceComponents($0, system: unitSystem)
      }
   }

   var climbAscentRemainingText: String? {
      progress.climbAscentRemaining.map {
         RideFormatters.elevation($0, system: unitSystem)
      }
   }

   var remainingGradeText: String? {
      progress.averageRemainingGrade.map(RideFormatters.grade)
   }

   // MARK: - Whole Route

   /// The ASC REMAINING tile and the between-climbs headline. `nil` hides both.
   var routeAscentRemainingText: String? {
      progress.routeAscentRemaining.map {
         RideFormatters.elevation($0, system: unitSystem)
      }
   }

   // MARK: - Next Climb

   var nextClimbCategoryLabel: String? { progress.nextClimb?.category.label }

   var nextClimbDistanceText: String? {
      guard let meters = progress.distanceToNextClimb else { return nil }
      return "in \(RouteGuidanceFormatters.turnDistance(meters, system: unitSystem))"
   }

   /// "+540 FT @ 5.4%" — what the next climb will cost.
   var nextClimbDemandText: String? {
      guard let next = progress.nextClimb else { return nil }
      let gain = PlannedRouteFormatters.elevationGain(next.ascent, system: unitSystem)
      return "\(gain) @ \(PlannedRouteFormatters.averageGrade(next.averageGrade))"
   }

   // MARK: - Freeride

   /// Climb-so-far figures, only while the live detector says this is a climb.
   var liveClimbAscentText: String? {
      guard liveClimb.isClimbing else { return nil }
      return RideFormatters.elevationGain(liveClimb.ascentSoFar, system: unitSystem)
   }

   var liveClimbDistanceText: String? {
      guard liveClimb.isClimbing else { return nil }
      let components = PlannedRouteFormatters.climbDistanceComponents(
         liveClimb.distanceSoFar,
         system: unitSystem
      )
      return "\(components.value) \(components.unit)"
   }

   var liveClimbGradeText: String? {
      guard liveClimb.isClimbing else { return nil }
      return "\(RideFormatters.grade(liveClimb.averageGrade))% avg"
   }
}
