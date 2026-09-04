//
//  RideInterruptionRecoveryTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

struct RideInterruptionRecoveryTests {

   // MARK: - Fixtures

   private let rideStart = Date(timeIntervalSince1970: 1_000_000)

   private func now(_ offset: TimeInterval) -> Date {
      rideStart.addingTimeInterval(offset)
   }

   private func checkpoint(
      phase: RidePhase = .recording,
      startDate: Date? = nil,
      at offset: TimeInterval
   ) -> RideSessionCheckpoint {
      RideSessionCheckpoint(
         phase: phase,
         startDate: startDate ?? rideStart,
         updatedAt: now(offset)
      )
   }

   private func decide(
      checkpoint: RideSessionCheckpoint?,
      distance: Double = 22_000,
      sampleCount: Int = 4_000,
      at offset: TimeInterval = 3_700
   ) -> RideInterruptionRecovery.Decision {
      RideInterruptionRecovery.decision(
         checkpoint: checkpoint,
         rideStartDate: rideStart,
         distance: distance,
         sampleCount: sampleCount,
         now: now(offset)
      )
   }

   // MARK: - Resuming

   @Test func aFreshInterruptionResumesTheRide() {
      let decision = decide(checkpoint: checkpoint(at: 3_600))

      #expect(decision == .resume(isPaused: false))
   }

   @Test func aRideThatWasPausedResumesPaused() {
      let decision = decide(checkpoint: checkpoint(phase: .paused, at: 3_600))

      #expect(decision == .resume(isPaused: true))
   }

   @Test func theEdgeOfTheResumeWindowStillResumes() {
      let decision = decide(
         checkpoint: checkpoint(at: 0),
         at: RideInterruptionRecovery.resumeWindow
      )

      #expect(decision == .resume(isPaused: false))
   }

   // MARK: - Closing Out

   @Test func anInterruptionOlderThanTheWindowIsFiledInsteadOfResumed() {
      let decision = decide(
         checkpoint: checkpoint(at: 0),
         at: RideInterruptionRecovery.resumeWindow + 1
      )

      #expect(decision == .closeOut)
   }

   @Test func aRideWithNoCheckpointIsFiledInHistory() {
      // What every ride an older build left open looks like: real distance on
      // disk, no `endDate`, and nothing to say the app died mid-ride.
      #expect(decide(checkpoint: nil) == .closeOut)
   }

   @Test func aCheckpointForADifferentRideDoesNotResumeThisOne() {
      let other = checkpoint(startDate: rideStart.addingTimeInterval(-9_000), at: 3_600)

      #expect(decide(checkpoint: other) == .closeOut)
   }

   @Test func aCheckpointFromAnEndedRideDoesNotResume() {
      #expect(decide(checkpoint: checkpoint(phase: .finished, at: 3_600)) == .closeOut)
   }

   @Test func aCheckpointFromTheFutureDoesNotResume() {
      // A clock that moved backwards must not make a stale checkpoint look
      // fresh forever.
      #expect(decide(checkpoint: checkpoint(at: 7_200), at: 3_600) == .closeOut)
   }

   // MARK: - Discarding

   @Test func anInterruptedRideThatWentNowhereIsDiscarded() {
      let decision = decide(
         checkpoint: checkpoint(at: 3_600),
         distance: 10,
         sampleCount: 30
      )

      #expect(decision == .discard(.insufficientDistance))
   }

   @Test func anInterruptedRideWithNoSamplesIsDiscarded() {
      let decision = decide(
         checkpoint: checkpoint(at: 3_600),
         distance: 0,
         sampleCount: 0
      )

      #expect(decision == .discard(.noSamples))
   }

   // MARK: - Checkpoint

   @Test func anUnknownPhaseReadsBackAsIdle() {
      let checkpoint = RideSessionCheckpoint(phase: .recording, startDate: rideStart)
      let data = try! JSONEncoder().encode(checkpoint)
      var fields = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
      fields["phaseRawValue"] = "teleporting"

      let mangled = try! JSONSerialization.data(withJSONObject: fields)
      let decoded = try! JSONDecoder().decode(RideSessionCheckpoint.self, from: mangled)

      #expect(decoded.phase == .idle)
      #expect(!decoded.phase.isActive)
   }
}
