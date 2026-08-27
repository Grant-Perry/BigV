//
//  RouteGuidanceFormattersTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

@MainActor
struct RouteGuidanceFormattersTests {

   // MARK: - Written Distance

   @Test func shortDistancesReadInRoundedFeet() {
      #expect(RouteGuidanceFormatters.turnDistance(30) == "100 ft")
      #expect(RouteGuidanceFormatters.turnDistance(152) == "500 ft")
   }

   @Test func longDistancesReadInMiles() {
      #expect(RouteGuidanceFormatters.turnDistance(1_609) == "1.0 mi")
      #expect(RouteGuidanceFormatters.turnDistance(805) == "0.5 mi")
      #expect(RouteGuidanceFormatters.turnDistance(24_140) == "15 mi")
   }

   @Test func aNegativeDistanceIsClampedRatherThanShown() {
      #expect(RouteGuidanceFormatters.turnDistance(-50) == "0 ft")
   }

   // MARK: - Spoken Distance

   @Test func spokenFeetAreRoundedHarderThanWrittenOnes() {
      #expect(RouteGuidanceFormatters.spokenDistance(30) == "100 feet")
      #expect(RouteGuidanceFormatters.spokenDistance(8) == "50 feet")
   }

   @Test func spokenMilesUseFractionsBelowOne() {
      #expect(RouteGuidanceFormatters.spokenDistance(805) == "half a mile")
      #expect(RouteGuidanceFormatters.spokenDistance(400) == "1 quarter of a mile")
      #expect(RouteGuidanceFormatters.spokenDistance(1_400) == "3 quarters of a mile")
   }

   @Test func aWholeNumberOfMilesIsSpokenWithoutADecimal() {
      #expect(RouteGuidanceFormatters.spokenDistance(1_609) == "1 mile")
      #expect(RouteGuidanceFormatters.spokenDistance(3_219) == "2 miles")
      #expect(RouteGuidanceFormatters.spokenDistance(2_500) == "1.6 miles")
   }

   // MARK: - Spoken Cues

   @Test func theCornerItselfIsAnnouncedWithoutADistance() {
      let cue = RouteGuidanceCue(
         maneuverID: 0,
         band: .now,
         instruction: "Turn left onto Elm Street",
         distance: 4
      )

      #expect(RouteGuidanceFormatters.spokenCue(cue) == "Turn left onto Elm Street")
   }

   @Test func anApproachIsAnnouncedWithADistanceFirst() {
      let cue = RouteGuidanceCue(
         maneuverID: 0,
         band: .near,
         instruction: "Turn left onto Elm Street",
         distance: 152
      )

      #expect(RouteGuidanceFormatters.spokenCue(cue) == "In 500 feet, turn left onto Elm Street")
   }

   /// Route shields and acronyms must not be lowercased into nonsense.
   @Test func anInstructionStartingWithAnAcronymKeepsItsCase() {
      let cue = RouteGuidanceCue(
         maneuverID: 0,
         band: .near,
         instruction: "NE Broadway",
         distance: 152
      )

      #expect(RouteGuidanceFormatters.spokenCue(cue) == "In 500 feet, NE Broadway")
   }

   @Test func anEmptyInstructionIsNotSpoken() {
      let cue = RouteGuidanceCue(maneuverID: 0, band: .now, instruction: "   ", distance: 0)

      #expect(RouteGuidanceFormatters.spokenCue(cue).isEmpty)
   }

   // MARK: - Arrival Time

   @Test func theArrivalClockIsTheEstimateAddedToNow() {
      let reference = Date(timeIntervalSince1970: 1_000_000)
      let expected = reference.addingTimeInterval(1_800).formatted(.dateTime.hour().minute())

      #expect(RouteGuidanceFormatters.arrivalTime(1_800, from: reference) == expected)
   }
}
