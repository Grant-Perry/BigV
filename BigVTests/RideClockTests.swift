//
//  RideClockTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

struct RideClockTests {

   // MARK: - Fixtures

   private let start = Date(timeIntervalSince1970: 1_000_000)

   private func date(_ offset: TimeInterval) -> Date {
      start.addingTimeInterval(offset)
   }

   // MARK: - Unpaused

   @Test func elapsedIsWallTimeWhenTheRideNeverPauses() {
      let clock = RideClock()

      #expect(clock.elapsed(since: start, at: date(600)) == 600)
   }

   @Test func elapsedNeverGoesNegative() {
      let clock = RideClock()

      #expect(clock.elapsed(since: start, at: date(-30)) == 0)
   }

   // MARK: - Closed Pauses

   @Test func aClosedPauseIsSubtracted() {
      var clock = RideClock()

      clock.beginPause(at: date(100))
      clock.endPause(at: date(160))

      #expect(clock.elapsed(since: start, at: date(600)) == 540)
   }

   @Test func pausesAccumulateAcrossARide() {
      var clock = RideClock()

      clock.beginPause(at: date(100))
      clock.endPause(at: date(130))
      clock.beginPause(at: date(300))
      clock.endPause(at: date(345))

      #expect(clock.elapsed(since: start, at: date(600)) == 525)
   }

   // MARK: - Open Pauses

   /// A rider staring at a paused dashboard must not watch the timer climb.
   @Test func anOpenPauseFreezesElapsedTime() {
      var clock = RideClock()

      clock.beginPause(at: date(200))

      #expect(clock.elapsed(since: start, at: date(400)) == 200)
      #expect(clock.elapsed(since: start, at: date(900)) == 200)
   }

   @Test func closingAnOpenPauseResumesTheClock() {
      var clock = RideClock()

      clock.beginPause(at: date(200))
      clock.endPause(at: date(500))

      #expect(clock.elapsed(since: start, at: date(600)) == 300)
   }

   // MARK: - Idempotence

   @Test func aSecondBeginPauseDoesNotRestartTheOpenPause() {
      var clock = RideClock()

      clock.beginPause(at: date(100))
      clock.beginPause(at: date(400))
      clock.endPause(at: date(500))

      #expect(clock.elapsed(since: start, at: date(600)) == 200)
   }

   /// `end()` closes a pause unconditionally, so this runs on every ride that
   /// finishes while recording.
   @Test func endPauseWithoutAnOpenPauseChangesNothing() {
      var clock = RideClock()

      clock.endPause(at: date(300))

      #expect(clock.elapsed(since: start, at: date(600)) == 600)
   }

   @Test func endPauseIsNotAppliedTwice() {
      var clock = RideClock()

      clock.beginPause(at: date(100))
      clock.endPause(at: date(160))
      clock.endPause(at: date(400))

      #expect(clock.elapsed(since: start, at: date(600)) == 540)
   }

   // MARK: - Reset

   @Test func resetClearsBothClosedAndOpenPauses() {
      var clock = RideClock()

      clock.beginPause(at: date(100))
      clock.endPause(at: date(160))
      clock.beginPause(at: date(200))
      clock.reset()

      #expect(clock.elapsed(since: start, at: date(600)) == 600)
   }

   // MARK: - Restore

   @Test func restoringResumesAtTheElapsedTimeTheRiderLastSaw() {
      var clock = RideClock()

      // Killed at 20 minutes of ride time, relaunched an hour after the start.
      clock.restore(elapsed: 1_200, since: start, at: date(3_600))

      #expect(clock.elapsed(since: start, at: date(3_600)) == 1_200)
   }

   @Test func timeTheAppWasDeadIsNotChargedToTheRider() {
      var clock = RideClock()

      clock.restore(elapsed: 1_200, since: start, at: date(3_600))

      // Ten more minutes of riding after the relaunch is ten more minutes.
      #expect(clock.elapsed(since: start, at: date(4_200)) == 1_800)
   }

   @Test func restoringClosesAnyOpenPause() {
      var clock = RideClock()

      clock.beginPause(at: date(100))
      clock.restore(elapsed: 90, since: start, at: date(600))

      #expect(clock.elapsed(since: start, at: date(600)) == 90)
   }

   @Test func restoringMoreElapsedThanWallTimeNeverRunsTheClockBackwards() {
      var clock = RideClock()

      clock.restore(elapsed: 9_000, since: start, at: date(600))

      #expect(clock.elapsed(since: start, at: date(600)) == 600)
   }
}
