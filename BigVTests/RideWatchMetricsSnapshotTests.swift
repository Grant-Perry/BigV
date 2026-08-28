//
//  RideWatchMetricsSnapshotTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

/// The projection from the phone's ride onto the wrist. Thin on purpose: anything
/// that leaks here is something the Watch could start deriving for itself.
@MainActor
struct RideWatchMetricsSnapshotTests {

   // MARK: - Fixtures

   private let reference = Date(timeIntervalSince1970: 1_000_000)

   private func recordingState() -> RideState {
      var state = RideState()
      state.phase = .recording
      state.startDate = reference
      state.speed = 8.4
      state.distance = 24_140.5
      state.elapsedTime = 1_800
      state.hasGPSFix = true
      state.isMoving = true
      return state
   }

   // MARK: - Projection

   @Test func everyMirroredFieldComesStraightFromRideState() {
      let snapshot = RideWatchMetricsSnapshot(state: recordingState(), capturedAt: reference)

      #expect(snapshot.phase == .recording)
      #expect(snapshot.speed == 8.4)
      #expect(snapshot.distance == 24_140.5)
      #expect(snapshot.elapsedTime == 1_800)
      #expect(snapshot.hasGPSFix)
      #expect(snapshot.isMoving)
      #expect(snapshot.capturedAt == reference)
   }

   @Test func afreshRideStateProjectsAnIdleGlance() {
      let snapshot = RideWatchMetricsSnapshot(state: RideState(), capturedAt: reference)

      #expect(snapshot.phase == .idle)
      #expect(snapshot.speed == 0)
      #expect(snapshot.distance == 0)
      #expect(snapshot.elapsedTime == 0)
      #expect(!snapshot.hasGPSFix)
      #expect(!snapshot.isMoving)
   }

   /// Heart rate travels the other way — the wrist measures it — so it must never
   /// ride along in the mirror.
   @Test func theMirrorCarriesNoSensorValuesBack() {
      var state = recordingState()
      state.heartRate = 142

      let payload = RideWatchMessage.metrics(
         RideWatchMetricsSnapshot(state: state, capturedAt: reference)
      ).payload
      let body = payload["body"] as? [String: Any]

      #expect(body?["heartRate"] == nil)
      #expect(body?["cadence"] == nil)
      #expect(body?["power"] == nil)
   }

   // MARK: - Round Trip

   @Test func theProjectionSurvivesTheWire() throws {
      let snapshot = RideWatchMetricsSnapshot(state: recordingState(), capturedAt: reference)
      let decoded = try #require(RideWatchMessage(payload: RideWatchMessage.metrics(snapshot).payload))

      guard case .metrics(let restored) = decoded else {
         Issue.record("Expected metrics, got \(decoded)")
         return
      }

      #expect(restored == snapshot)
   }
}
