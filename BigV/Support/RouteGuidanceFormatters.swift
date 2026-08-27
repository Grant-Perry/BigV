//
//  RouteGuidanceFormatters.swift
//  BigV
//

import CoreLocation
import Foundation

/// Turns guidance figures into what a rider reads on a handlebar and hears in an
/// earpiece.
///
/// Separate from `PlannedRouteFormatters` because guidance units read differently:
/// a route is chosen in miles from a list, but a turn is approached in feet, and
/// the spoken form of a distance is not the written one.
enum RouteGuidanceFormatters {

   // MARK: - Constants

   private static let metersPerFoot: Double = 0.3048
   private static let metersPerMile: Double = 1_609.344

   /// Below this, distance to a turn reads in feet. A tenth of a mile is where
   /// feet stop being a number a rider can act on.
   private static let feetCeiling: Double = 300

   // MARK: - Turn Distance

   /// Distance to a maneuver, written.
   static func turnDistance(_ meters: CLLocationDistance) -> String {
      let clamped = max(0, meters)

      guard clamped >= feetCeiling else {
         let feet = (clamped / metersPerFoot / 10).rounded() * 10
         return "\(Int(feet)) ft"
      }

      let miles = clamped / metersPerMile
      return "\(miles.formatted(.number.precision(.fractionLength(miles < 10 ? 1 : 0)))) mi"
   }

   /// Distance to a maneuver, spoken. Rounded harder than the written form
   /// because "four hundred and thirty feet" is noise at 20 mph.
   static func spokenDistance(_ meters: CLLocationDistance) -> String {
      let clamped = max(0, meters)

      guard clamped >= feetCeiling else {
         let feet = (clamped / metersPerFoot / 50).rounded() * 50
         return "\(Int(max(50, feet))) feet"
      }

      let miles = clamped / metersPerMile

      // Under a mile a rider hears fractions better than decimals: "half a mile"
      // lands, "zero point five miles" does not.
      guard miles >= 0.95 else {
         let quarters = min(3, max(1, (miles * 4).rounded()))
         return quarters == 2
            ? "half a mile"
            : "\(Int(quarters)) quarter\(quarters > 1 ? "s" : "") of a mile"
      }

      let rounded = (miles * 10).rounded() / 10

      guard rounded != 1 else { return "1 mile" }

      let value = rounded == rounded.rounded()
         ? "\(Int(rounded))"
         : rounded.formatted(.number.precision(.fractionLength(1)))

      return "\(value) miles"
   }

   // MARK: - Remaining

   static func distanceRemaining(_ meters: CLLocationDistance) -> String {
      RideFormatters.distance(max(0, meters))
   }

   static func timeRemaining(_ seconds: TimeInterval) -> String {
      PlannedRouteFormatters.travelTime(seconds)
   }

   /// Clock time the rider is expected to arrive, which is the figure they
   /// actually plan around.
   static func arrivalTime(_ seconds: TimeInterval, from reference: Date = .now) -> String {
      reference
         .addingTimeInterval(max(0, seconds))
         .formatted(.dateTime.hour().minute())
   }

   // MARK: - Spoken Cues

   /// What to say for one cue band.
   ///
   /// The corner itself gets the bare instruction: at eight meters, a distance is
   /// information the rider no longer has time for.
   static func spokenCue(_ cue: RouteGuidanceCue) -> String {
      let instruction = cue.instruction.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !instruction.isEmpty else { return "" }

      return switch cue.band {
         case .now: instruction
         default: "In \(spokenDistance(cue.distance)), \(lowercasedFirstWord(instruction))"
      }
   }

   /// Instructions arrive sentence-cased from the provider, which reads wrong
   /// mid-sentence after "In 500 feet".
   private static func lowercasedFirstWord(_ instruction: String) -> String {
      guard let first = instruction.first, first.isUppercase else { return instruction }

      // Acronyms and route shields ("NE Broadway", "SR 520") must keep their case.
      let secondIsUppercase = instruction.dropFirst().first?.isUppercase ?? false
      guard !secondIsUppercase else { return instruction }

      return instruction.replacingCharacters(
         in: instruction.startIndex...instruction.startIndex,
         with: first.lowercased()
      )
   }
}
