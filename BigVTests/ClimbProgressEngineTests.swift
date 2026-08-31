//
//  ClimbProgressEngineTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

@MainActor
struct ClimbProgressEngineTests {

   // MARK: - Fixtures

   /// 1 km flat at 100 m, 1 km rising to 150 m (5%), 1 km flat: one climb in
   /// the middle with clean numbers on both sides.
   private func makeEngine() -> ClimbProgressEngine {
      var samples: [RouteElevationSample] = []
      for step in 0...30 {
         let distance = Double(step) * 100
         let altitude: Double = switch distance {
            case ..<1_000: 100
            case ..<2_000: 100 + (distance - 1_000) * 0.05
            default: 150
         }
         samples.append(RouteElevationSample(distanceAlongRoute: distance, altitude: altitude))
      }

      let climb = PlannedClimb(
         id: 0,
         startDistance: 1_000,
         endDistance: 2_000,
         ascent: 50,
         averageGrade: 5,
         category: .uncategorized
      )

      var engine = ClimbProgressEngine()
      engine.prepare(profile: samples, climbs: [climb])
      return engine
   }

   // MARK: - Readiness

   @Test func anUnpreparedEngineAnswersNone() {
      let engine = ClimbProgressEngine()
      #expect(!engine.isReady)
      #expect(engine.progress(at: 500) == .none)
   }

   @Test func resetForgetsTheRoute() {
      var engine = makeEngine()
      engine.reset()
      #expect(!engine.isReady)
      #expect(engine.progress(at: 500) == .none)
   }

   // MARK: - Whole Route

   @Test func routeAscentRemainingCountsDownFromTheTotal() throws {
      let engine = makeEngine()

      let atStart = engine.progress(at: 0)
      #expect(atStart.hasRouteProfile)
      #expect(abs(try #require(atStart.routeAscentRemaining) - 50) < 0.5)

      // Halfway up the climb, half the route's ascent is banked.
      let halfway = engine.progress(at: 1_500)
      #expect(abs(try #require(halfway.routeAscentRemaining) - 25) < 0.5)

      let done = engine.progress(at: 3_000)
      #expect(abs(try #require(done.routeAscentRemaining)) < 0.5)
   }

   @Test func thePlayheadInterpolatesBetweenSamples() throws {
      let engine = makeEngine()

      // 1 550 m sits mid-segment; altitude must interpolate, not snap.
      let progress = engine.progress(at: 1_550)
      #expect(try #require(progress.playheadDistance) == 1_550)
      #expect(abs(try #require(progress.playheadAltitude) - 127.5) < 0.1)
   }

   // MARK: - This Climb

   @Test func onTheClimbTheRemainingMathIsExact() throws {
      let engine = makeEngine()

      let progress = engine.progress(at: 1_500)
      #expect(progress.activeClimb?.id == 0)
      #expect(try #require(progress.distanceToTop) == 500)
      #expect(abs(try #require(progress.climbAscentRemaining) - 25) < 0.5)
      #expect(abs(try #require(progress.averageRemainingGrade) - 5) < 0.1)
   }

   @Test func beforeTheBaseThereIsNoActiveClimb() {
      let engine = makeEngine()

      let progress = engine.progress(at: 500)
      #expect(progress.activeClimb == nil)
      #expect(progress.distanceToTop == nil)
      #expect(progress.climbAscentRemaining == nil)
   }

   @Test func atTheCrestTheClimbIsOver() {
      let engine = makeEngine()

      // `contains` is half-open: the end distance is off the climb, so the
      // page flips from "to top 0" to "between climbs" exactly at the crest.
      #expect(engine.progress(at: 2_000).activeClimb == nil)
      #expect(engine.progress(at: 1_999).activeClimb?.id == 0)
   }

   // MARK: - Next Climb

   @Test func theNextClimbIsAnnouncedWithItsDistance() throws {
      let engine = makeEngine()

      let progress = engine.progress(at: 400)
      #expect(progress.nextClimb?.id == 0)
      #expect(try #require(progress.distanceToNextClimb) == 600)
   }

   @Test func pastTheLastClimbNothingIsNext() {
      let engine = makeEngine()

      let progress = engine.progress(at: 2_500)
      #expect(progress.nextClimb == nil)
      #expect(progress.distanceToNextClimb == nil)
   }

   @Test func progressClampsOffTheEndsOfTheRoute() throws {
      let engine = makeEngine()

      // A guidance scalar slightly outside the profile must not crash or
      // invent numbers — it clamps to the ends.
      let before = engine.progress(at: -50)
      #expect(try #require(before.playheadDistance) == 0)

      let after = engine.progress(at: 9_999)
      #expect(try #require(after.playheadDistance) == 3_000)
      #expect(abs(try #require(after.routeAscentRemaining)) < 0.5)
   }
}
