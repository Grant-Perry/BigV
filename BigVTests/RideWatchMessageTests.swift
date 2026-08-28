//
//  RideWatchMessageTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

/// The wire format between the wrist and the phone. Every one of these runs
/// without a paired Watch, because the codec is pure.
struct RideWatchMessageTests {

   // MARK: - Fixtures

   private let reference = Date(timeIntervalSince1970: 1_000_000)

   private func snapshot(phase: RidePhase = .recording) -> RideWatchMetricsSnapshot {
      RideWatchMetricsSnapshot(
         phase: phase,
         speed: 8.4,
         distance: 24_140.5,
         elapsedTime: 1_800,
         hasGPSFix: true,
         isMoving: true,
         capturedAt: reference
      )
   }

   private func roundTrip(_ message: RideWatchMessage) -> RideWatchMessage? {
      RideWatchMessage(payload: message.payload)
   }

   // MARK: - Metrics

   @Test func metricsSurviveARoundTrip() throws {
      let decoded = try #require(roundTrip(.metrics(snapshot())))

      guard case .metrics(let restored) = decoded else {
         Issue.record("Expected metrics, got \(decoded)")
         return
      }

      #expect(restored == snapshot())
   }

   @Test(arguments: RidePhase.allCases)
   func everyPhaseSurvivesARoundTrip(phase: RidePhase) throws {
      let decoded = try #require(roundTrip(.metrics(snapshot(phase: phase))))

      guard case .metrics(let restored) = decoded else {
         Issue.record("Expected metrics, got \(decoded)")
         return
      }

      #expect(restored.phase == phase)
   }

   @Test func metricsPayloadCarriesOnlyPropertyListValues() {
      let payload = RideWatchMessage.metrics(snapshot()).payload

      #expect(PropertyListSerialization.propertyList(payload, isValidFor: .binary))
   }

   // MARK: - Heart Rate

   @Test func heartRateSurvivesARoundTrip() throws {
      let reading = RideWatchHeartRateReading(beatsPerMinute: 142, measuredAt: reference)
      let decoded = try #require(roundTrip(.heartRate(reading)))

      guard case .heartRate(let restored) = decoded else {
         Issue.record("Expected heart rate, got \(decoded)")
         return
      }

      #expect(restored == reading)
   }

   @Test func heartRateEndedSurvivesARoundTripWithNoBody() throws {
      let decoded = try #require(roundTrip(.heartRateEnded))

      #expect(decoded == .heartRateEnded)
   }

   // MARK: - Commands

   @Test(arguments: RideRemoteCommand.allCases)
   func everyCommandSurvivesARoundTrip(command: RideRemoteCommand) throws {
      let request = RideRemoteCommandRequest(command: command, sentAt: reference)
      let decoded = try #require(roundTrip(.command(request)))

      guard case .command(let restored) = decoded else {
         Issue.record("Expected command, got \(decoded)")
         return
      }

      #expect(restored == request)
   }

   @Test func receiptSurvivesARoundTrip() throws {
      let receipt = RideRemoteCommandReceipt(outcome: .ignoredForPhase, phase: .paused)
      let decoded = try #require(roundTrip(.commandReceipt(receipt)))

      guard case .commandReceipt(let restored) = decoded else {
         Issue.record("Expected receipt, got \(decoded)")
         return
      }

      #expect(restored == receipt)
   }

   // MARK: - Rejection

   @Test func anEmptyPayloadDecodesToNothing() {
      #expect(RideWatchMessage(payload: [:]) == nil)
   }

   /// A counterpart on a newer build must never be able to break this one.
   @Test func anUnknownKindDecodesToNothing() {
      #expect(RideWatchMessage(payload: ["kind": "cadence", "body": [:]]) == nil)
   }

   @Test func aTruncatedBodyDecodesToNothing() {
      var payload = RideWatchMessage.metrics(snapshot()).payload
      var body = payload["body"] as? [String: Any]
      body?.removeValue(forKey: "distance")
      payload["body"] = body

      #expect(RideWatchMessage(payload: payload) == nil)
   }

   @Test func anUnparseablePhaseDecodesToNothing() {
      var payload = RideWatchMessage.metrics(snapshot()).payload
      var body = payload["body"] as? [String: Any]
      body?["phase"] = "coasting"
      payload["body"] = body

      #expect(RideWatchMessage(payload: payload) == nil)
   }

   @Test func aCommandWithoutATimestampDecodesToNothing() {
      #expect(RideWatchMessage(payload: ["kind": "command", "body": ["command": "start"]]) == nil)
   }

   // MARK: - Freshness

   @Test func aSnapshotIsStaleOnceItsWindowHasPassed() {
      let snapshot = snapshot()

      #expect(snapshot.isFresh(at: reference.addingTimeInterval(4), within: 8))
      #expect(!snapshot.isFresh(at: reference.addingTimeInterval(30), within: 8))
   }

   @Test func aReadingIsStaleOnceItsWindowHasPassed() {
      let reading = RideWatchHeartRateReading(beatsPerMinute: 142, measuredAt: reference)

      #expect(reading.isFresh(at: reference.addingTimeInterval(5), within: 10))
      #expect(!reading.isFresh(at: reference.addingTimeInterval(45), within: 10))
   }

   @Test(arguments: [0.0, 12.0, 24.0, 260.0, 400.0])
   func implausibleHeartRatesAreRejected(beatsPerMinute: Double) {
      let reading = RideWatchHeartRateReading(beatsPerMinute: beatsPerMinute, measuredAt: reference)

      #expect(!reading.isPlausible)
   }

   @Test(arguments: [25.0, 60.0, 142.0, 205.0, 240.0])
   func plausibleHeartRatesAreAccepted(beatsPerMinute: Double) {
      let reading = RideWatchHeartRateReading(beatsPerMinute: beatsPerMinute, measuredAt: reference)

      #expect(reading.isPlausible)
   }
}
