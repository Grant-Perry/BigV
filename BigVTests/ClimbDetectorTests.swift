//
//  ClimbDetectorTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

@MainActor
struct ClimbDetectorTests {

   // MARK: - Fixtures

   /// A profile stitched from (length, grade%) legs, sampled every 100 m, so a
   /// test reads like a road book: flat, climb, descent.
   private func profile(legs: [(length: Double, grade: Double)]) -> [RouteElevationSample] {
      var samples = [RouteElevationSample(distanceAlongRoute: 0, altitude: 100)]
      var distance: Double = 0
      var altitude: Double = 100

      for leg in legs {
         let end = distance + leg.length
         while distance < end {
            let step = min(100, end - distance)
            distance += step
            altitude += step * leg.grade / 100
            samples.append(RouteElevationSample(distanceAlongRoute: distance, altitude: altitude))
         }
      }

      return samples
   }

   // MARK: - Gate

   @Test func aLongSteadyRiseIsOneClimb() throws {
      let climbs = ClimbDetector.climbs(in: profile(legs: [
         (length: 1_000, grade: 0),
         (length: 4_000, grade: 5),
         (length: 1_000, grade: 0)
      ]))

      let climb = try #require(climbs.first)
      #expect(climbs.count == 1)
      #expect(climb.startDistance == 1_000)
      #expect(climb.endDistance == 5_000)
      #expect(abs(climb.ascent - 200) < 0.5)
      #expect(abs(climb.averageGrade - 5) < 0.1)
   }

   @Test func tooShortDoesNotGate() {
      // 400 m at 6% is steep but not a climb by the 500 m gate.
      let climbs = ClimbDetector.climbs(in: profile(legs: [
         (length: 400, grade: 6),
         (length: 1_000, grade: -2)
      ]))

      #expect(climbs.isEmpty)
   }

   @Test func tooShallowDoesNotGate() {
      // 1 km at 2% never reaches the 3% floor.
      let climbs = ClimbDetector.climbs(in: profile(legs: [
         (length: 1_000, grade: 2),
         (length: 1_000, grade: -2)
      ]))

      #expect(climbs.isEmpty)
   }

   @Test func aFlatProfileHasNoClimbs() {
      #expect(ClimbDetector.climbs(in: profile(legs: [(length: 5_000, grade: 0)])).isEmpty)
      #expect(ClimbDetector.climbs(in: []).isEmpty)
   }

   // MARK: - Categories

   @Test func scoreDrawsTheGarminCategories() {
      // grade% × length m: 90 000 HC, 70 000 Cat 1, 40 000 Cat 2,
      // 20 000 Cat 3, 9 000 Cat 4, 2 100 uncategorized.
      let expectations: [(length: Double, grade: Double, category: ClimbCategory)] = [
         (10_000, 9, .hors),
         (10_000, 7, .one),
         (8_000, 5, .two),
         (4_000, 5, .three),
         (2_000, 4.5, .four),
         (600, 3.5, .uncategorized)
      ]

      for expectation in expectations {
         let climbs = ClimbDetector.climbs(in: profile(legs: [
            (length: expectation.length, grade: expectation.grade),
            (length: 1_000, grade: -3)
         ]))

         #expect(climbs.first?.category == expectation.category, "\(expectation)")
      }
   }

   // MARK: - Interruptions

   @Test func aShortShallowDipDoesNotSplitAClimb() throws {
      // Two 2 km / 5% ramps around a 200 m dip giving back 8 m: one climb,
      // the false flat folded in.
      let climbs = ClimbDetector.climbs(in: profile(legs: [
         (length: 2_000, grade: 5),
         (length: 200, grade: -4),
         (length: 2_000, grade: 5)
      ]))

      let climb = try #require(climbs.first)
      #expect(climbs.count == 1)
      #expect(climb.startDistance == 0)
      #expect(climb.endDistance == 4_200)
      #expect(abs(climb.ascent - 192) < 0.5)
   }

   @Test func aRealDescentEndsTheClimb() {
      // The middle leg drops 40 m over 800 m — a descent, not a saddle — so
      // the ramps stay two separate climbs.
      let climbs = ClimbDetector.climbs(in: profile(legs: [
         (length: 2_000, grade: 5),
         (length: 800, grade: -5),
         (length: 2_000, grade: 5)
      ]))

      #expect(climbs.count == 2)
      #expect(climbs[0].endDistance == 2_000)
      #expect(climbs[1].startDistance == 2_800)
      #expect(climbs[0].id == 0)
      #expect(climbs[1].id == 1)
   }
}
