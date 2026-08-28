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

   private func radarState() -> RideState {
      var state = recordingState()
      state.radar.connection = .connected
      state.radar.aggregateTier = .high
      state.radar.nearestDistanceMeters = 23
      state.radar.alertPulse = 4
      state.radar.clearPulse = 1
      state.radar.tracks = [
         RideRadarTracker.Track(
            id: 3,
            distanceMeters: 23,
            closingSpeedMetersPerSecond: 9,
            timeToContact: 2.5,
            tier: .high,
            firstSeenAt: reference,
            lastSeenAt: reference,
            minimumDistanceMeters: 23,
            maximumClosingSpeedMetersPerSecond: 9,
            peakTier: .high
         )
      ]
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

   @Test func aLocationIssueAndAccuracyRideOnTheMirror() {
      var state = recordingState()
      state.phase = .acquiringGPS
      state.hasGPSFix = false
      state.locationIssue = .temporarilyUnavailable
      state.horizontalAccuracy = 48

      let snapshot = RideWatchMetricsSnapshot(state: state, capturedAt: reference)

      #expect(snapshot.locationIssue == "No phone GPS yet")
      #expect(snapshot.horizontalAccuracy == 48)
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

   // MARK: - Units

   @Test func theUnitSystemRidesTheWire() throws {
      let snapshot = RideWatchMetricsSnapshot(
         phase: .recording,
         speed: 5,
         distance: 100,
         elapsedTime: 60,
         hasGPSFix: true,
         isMoving: true,
         unitSystem: .metric
      )
      let decoded = try #require(RideWatchMetricsSnapshot(body: snapshot.body))
      #expect(decoded.unitSystem == .metric)
   }

   @Test func aPayloadWithoutUnitsDecodesAsImperial() throws {
      // A phone build that predates the units feature sends no key; the
      // wrist must fall back to the app default, never crash or go metric.
      var body = RideWatchMetricsSnapshot(
         phase: .idle,
         speed: 0,
         distance: 0,
         elapsedTime: 0,
         hasGPSFix: false,
         isMoving: false
      ).body
      body["units"] = nil

      let decoded = try #require(RideWatchMetricsSnapshot(body: body))
      #expect(decoded.unitSystem == .imperial)
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

   // MARK: - Radar

   @Test func radarRidesTheMirrorOnlyWhenTheLinkIsLive() {
      let state = radarState()

      let withRadar = RideWatchMetricsSnapshot(
         state: state, capturedAt: reference, includesRadar: true
      )
      #expect(withRadar.radarConnected == true)
      #expect(withRadar.radarTier == .high)
      #expect(withRadar.radarCount == 1)
      #expect(withRadar.radarNearest == 23)
      #expect(withRadar.radarAlertPulse == 4)
      #expect(withRadar.radarClearPulse == 1)

      // Without a live link the fields stay home even when stale state
      // lingers, so a radar-less wrist never grows a radar pip.
      let withoutRadar = RideWatchMetricsSnapshot(state: state, capturedAt: reference)
      #expect(withoutRadar.radarConnected == nil)
      #expect(withoutRadar.radarTier == nil)
      #expect(withoutRadar.radarCount == nil)
      #expect(withoutRadar.radarNearest == nil)
      #expect(withoutRadar.radarAlertPulse == nil)
      #expect(withoutRadar.radarClearPulse == nil)
   }

   @Test func theRadarProjectionSurvivesTheWire() throws {
      let snapshot = RideWatchMetricsSnapshot(
         state: radarState(), capturedAt: reference, includesRadar: true
      )
      let decoded = try #require(RideWatchMessage(payload: RideWatchMessage.metrics(snapshot).payload))

      guard case .metrics(let restored) = decoded else {
         Issue.record("Expected metrics, got \(decoded)")
         return
      }

      #expect(restored == snapshot)
      #expect(restored.radarTier == .high)
      #expect(restored.radarAlertPulse == 4)
   }

   /// A payload from a phone build that predates radar carries none of the
   /// radar keys, and must decode to a snapshot with every radar field `nil`.
   @Test func aLegacyPayloadWithoutRadarKeysDecodesToNoRadar() throws {
      let legacyBody: [String: Any] = [
         "phase": RidePhase.recording.rawValue,
         "speed": 8.4,
         "distance": 24_140.5,
         "elapsedTime": 1_800.0,
         "hasGPSFix": true,
         "isMoving": true,
         "capturedAt": reference.timeIntervalSince1970
      ]

      let snapshot = try #require(RideWatchMetricsSnapshot(body: legacyBody))

      #expect(snapshot.phase == .recording)
      #expect(snapshot.radarConnected == nil)
      #expect(snapshot.radarTier == nil)
      #expect(snapshot.radarCount == nil)
      #expect(snapshot.radarNearest == nil)
      #expect(snapshot.radarAlertPulse == nil)
      #expect(snapshot.radarClearPulse == nil)
   }

   /// WatchConnectivity rejects anything that is not a property list, so the
   /// radar-bearing payload has to serialize cleanly.
   @Test func theRadarPayloadIsAValidPropertyList() throws {
      let payload = RideWatchMessage.metrics(
         RideWatchMetricsSnapshot(
            state: radarState(), capturedAt: reference, includesRadar: true
         )
      ).payload

      let data = try PropertyListSerialization.data(
         fromPropertyList: payload, format: .binary, options: 0
      )

      #expect(!data.isEmpty)
   }
}
