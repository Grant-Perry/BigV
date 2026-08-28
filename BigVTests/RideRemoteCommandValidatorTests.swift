//
//  RideRemoteCommandValidatorTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

/// The full decision table for a command arriving from the wrist.
struct RideRemoteCommandValidatorTests {

   // MARK: - Fixtures

   private let reference = Date(timeIntervalSince1970: 1_000_000)

   private func evaluate(
      _ command: RideRemoteCommand,
      phase: RidePhase,
      age: TimeInterval = 0
   ) -> RideRemoteCommandOutcome {
      RideRemoteCommandValidator.evaluate(
         RideRemoteCommandRequest(command: command, sentAt: reference),
         phase: phase,
         now: reference.addingTimeInterval(age)
      )
   }

   // MARK: - Permitted Phases

   /// These mirror the guards inside `RideSessionManager`. If one drifts, the
   /// Watch starts lying to the rider about why nothing happened.
   @Test func startIsPermittedOnlyWhenNoRideIsUnderway() {
      #expect(evaluate(.start, phase: .idle) == .accepted)
      #expect(evaluate(.start, phase: .finished) == .accepted)
      #expect(evaluate(.start, phase: .acquiringGPS) == .ignoredForPhase)
      #expect(evaluate(.start, phase: .recording) == .ignoredForPhase)
      #expect(evaluate(.start, phase: .paused) == .ignoredForPhase)
   }

   @Test func pauseIsPermittedOnlyWhileRecording() {
      #expect(evaluate(.pause, phase: .recording) == .accepted)
      #expect(evaluate(.pause, phase: .idle) == .ignoredForPhase)
      #expect(evaluate(.pause, phase: .acquiringGPS) == .ignoredForPhase)
      #expect(evaluate(.pause, phase: .paused) == .ignoredForPhase)
      #expect(evaluate(.pause, phase: .finished) == .ignoredForPhase)
   }

   @Test func resumeIsPermittedOnlyWhilePaused() {
      #expect(evaluate(.resume, phase: .paused) == .accepted)
      #expect(evaluate(.resume, phase: .idle) == .ignoredForPhase)
      #expect(evaluate(.resume, phase: .acquiringGPS) == .ignoredForPhase)
      #expect(evaluate(.resume, phase: .recording) == .ignoredForPhase)
      #expect(evaluate(.resume, phase: .finished) == .ignoredForPhase)
   }

   @Test func endIsPermittedWheneverARideIsUnderway() {
      #expect(evaluate(.end, phase: .acquiringGPS) == .accepted)
      #expect(evaluate(.end, phase: .recording) == .accepted)
      #expect(evaluate(.end, phase: .paused) == .accepted)
      #expect(evaluate(.end, phase: .idle) == .ignoredForPhase)
      #expect(evaluate(.end, phase: .finished) == .ignoredForPhase)
   }

   @Test(arguments: RideRemoteCommand.allCases, RidePhase.allCases)
   func permissionAgreesWithTheValidator(command: RideRemoteCommand, phase: RidePhase) {
      let expected: RideRemoteCommandOutcome = command.isPermitted(in: phase) ? .accepted : .ignoredForPhase

      #expect(evaluate(command, phase: phase) == expected)
   }

   // MARK: - Freshness

   @Test func aCommandInsideTheWindowIsJudgedOnPhaseAlone() {
      #expect(evaluate(.start, phase: .idle, age: 14) == .accepted)
   }

   @Test func aCommandThatSatInAQueueTooLongExpires() {
      #expect(evaluate(.start, phase: .idle, age: 16) == .expired)
      #expect(evaluate(.start, phase: .idle, age: 600) == .expired)
   }

   /// A START delivered ten minutes late would begin a ride nobody asked for, so
   /// staleness outranks a phase that would otherwise accept it.
   @Test func expiryOutranksPhasePermission() {
      #expect(evaluate(.pause, phase: .idle, age: 600) == .expired)
   }

   @Test func exactlyAtTheBoundaryTheCommandStillCounts() {
      #expect(evaluate(.start, phase: .idle, age: RideRemoteCommandValidator.freshnessWindow) == .accepted)
   }

   /// A Watch whose clock runs ahead of the phone must not be trusted any further
   /// than one running behind it.
   @Test func aCommandFromTheFutureExpiresJustTheSame() {
      #expect(evaluate(.start, phase: .idle, age: -16) == .expired)
      #expect(evaluate(.start, phase: .idle, age: -5) == .accepted)
   }

   @Test func aWiderWindowCanBeAskedFor() {
      let request = RideRemoteCommandRequest(command: .start, sentAt: reference)
      let outcome = RideRemoteCommandValidator.evaluate(
         request,
         phase: .idle,
         now: reference.addingTimeInterval(45),
         freshnessWindow: 60
      )

      #expect(outcome == .accepted)
   }

   // MARK: - Presentation

   @Test func onlyAnAcceptedCommandStaysSilent() {
      #expect(RideRemoteCommandOutcome.accepted.message == nil)

      for outcome in RideRemoteCommandOutcome.allCases where outcome != .accepted {
         #expect(outcome.message != nil)
      }
   }
}
