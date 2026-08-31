//
//  LiveClimbDetectorTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

@MainActor
struct LiveClimbDetectorTests {

   private static let reference = Date(timeIntervalSince1970: 1_000_000)

   /// Feeds a (length, grade%) leg into the detector in 50 m steps at 5 m/s,
   /// returning the last completed climb any step reported.
   private func ride(
      _ detector: inout LiveClimbDetector,
      legs: [(length: Double, grade: Double)]
   ) -> LiveClimbDetector.CompletedClimb? {
      var distance: Double = 0
      var altitude: Double = 100
      var completed: LiveClimbDetector.CompletedClimb?

      // The stationary start anchors the base at distance zero.
      _ = detector.ingest(distance: 0, altitude: altitude, timestamp: Self.reference)

      for leg in legs {
         let end = distance + leg.length
         while distance < end {
            let step = min(50, end - distance)
            distance += step
            altitude += step * leg.grade / 100

            let finished = detector.ingest(
               distance: distance,
               altitude: altitude,
               timestamp: Self.reference.addingTimeInterval(distance / 5)
            )
            if let finished { completed = finished }
         }
      }

      return completed
   }

   // MARK: - Status

   @Test func aQualifyingRiseReportsClimbSoFar() {
      var detector = LiveClimbDetector()
      _ = ride(&detector, legs: [(length: 1_000, grade: 5)])

      #expect(detector.status.isClimbing)
      #expect(abs(detector.status.distanceSoFar - 1_000) < 1)
      #expect(abs(detector.status.ascentSoFar - 50) < 0.5)
      #expect(abs(detector.status.averageGrade - 5) < 0.2)
   }

   @Test func aShortOrShallowEffortIsNotAClimb() {
      var shortDetector = LiveClimbDetector()
      _ = ride(&shortDetector, legs: [(length: 400, grade: 8)])
      #expect(!shortDetector.status.isClimbing)

      var shallowDetector = LiveClimbDetector()
      _ = ride(&shallowDetector, legs: [(length: 2_000, grade: 1.5)])
      #expect(!shallowDetector.status.isClimbing)
   }

   @Test func aToleratedDipStaysInsideTheClimb() {
      var detector = LiveClimbDetector()
      // 8 m given back over 150 m is a saddle, not a descent.
      _ = ride(&detector, legs: [
         (length: 1_000, grade: 5),
         (length: 150, grade: -5),
         (length: 500, grade: 5)
      ])

      #expect(detector.status.isClimbing)
      #expect(abs(detector.status.distanceSoFar - 1_650) < 1)
   }

   // MARK: - Completion

   @Test func aRealDescentCutsTheClimbAtItsPeak() throws {
      var detector = LiveClimbDetector()
      let finished = ride(&detector, legs: [
         (length: 1_000, grade: 5),
         (length: 600, grade: -5)
      ])
      let completed = try #require(finished)

      #expect(completed.startDistance == 0)
      #expect(completed.endDistance == 1_000)
      #expect(abs(completed.ascent - 50) < 0.5)
      #expect(abs(completed.averageGrade - 5) < 0.2)

      // 5% × 1 000 m scores 5 000 — a real climb, but no category.
      #expect(completed.category == .uncategorized)

      // The crest timestamp, not the moment the descent confirmed it.
      #expect(completed.endedAt == Self.reference.addingTimeInterval(1_000 / 5))
      #expect(!detector.status.isClimbing)
   }

   @Test func anUnqualifiedRiseEndsWithNoSplit() {
      var detector = LiveClimbDetector()
      // Rose 300 m then descended: never met the gate, nothing to cut.
      let completed = ride(&detector, legs: [
         (length: 300, grade: 5),
         (length: 600, grade: -5)
      ])

      #expect(completed == nil)
   }

   @Test func resetForgetsTheRoad() {
      var detector = LiveClimbDetector()
      _ = ride(&detector, legs: [(length: 1_000, grade: 5)])

      detector.reset()
      #expect(detector.status == .idle)
   }
}
