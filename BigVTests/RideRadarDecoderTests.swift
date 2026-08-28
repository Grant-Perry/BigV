//
//  RideRadarDecoderTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

struct RideRadarDecoderTests {

   private let reference = Date(timeIntervalSince1970: 1_700_000_000)

   // MARK: - Heartbeats

   @Test func aSingleByteWithTheThreatNibbleIsAHeartbeat() {
      let classification = RideRadarDecoder.classify([0x32], receivedAt: reference)

      guard case .heartbeat(let frame) = classification else {
         Issue.record("Expected a heartbeat, got \(classification)")
         return
      }

      #expect(frame.sequence == 3)
      #expect(frame.targets.isEmpty)
      #expect(frame.isHeartbeat)
      #expect(frame.receivedAt == reference)
   }

   // MARK: - Real Capture

   @Test func theRealCapturedFrameDecodesToOneVehicleAtFiveMeters() {
      // Captured from a Garmin radar: seq 0xA, track 0x20, 5 m, speed byte 0.
      let classification = RideRadarDecoder.classify([0xA2, 0xA0, 0x05, 0x00])

      guard case .threat(let frame) = classification else {
         Issue.record("Expected a threat frame, got \(classification)")
         return
      }

      #expect(frame.sequence == 0xA)
      #expect(frame.targets.count == 1)
      #expect(frame.targets.first?.trackID == 0x20)
      #expect(frame.targets.first?.distanceMeters == 5)
      #expect(frame.targets.first?.rawSpeedByte == 0)
   }

   // MARK: - Multiple Vehicles

   @Test func twoVehiclesRideOneNotification() {
      let payload: [UInt8] = [0x12, 0x81, 0x1E, 0x05, 0x82, 0x50, 0x0A]
      let classification = RideRadarDecoder.classify(payload)

      guard case .threat(let frame) = classification else {
         Issue.record("Expected a threat frame, got \(classification)")
         return
      }

      #expect(frame.targets.count == 2)
      #expect(frame.targets[0].trackID == 0x01)
      #expect(frame.targets[0].distanceMeters == 30)
      #expect(frame.targets[0].rawSpeedByte == 0x05)
      #expect(frame.targets[1].trackID == 0x02)
      #expect(frame.targets[1].distanceMeters == 80)
   }

   @Test func sixVehiclesFillTheNineteenBytePayload() {
      var payload: [UInt8] = [0x22]
      for index in UInt8(1)...6 {
         payload.append(contentsOf: [0x80 | index, index * 10, 0x00])
      }

      guard case .threat(let frame) = RideRadarDecoder.classify(payload) else {
         Issue.record("Expected a threat frame")
         return
      }

      #expect(payload.count == 19)
      #expect(frame.targets.count == 6)
      #expect(frame.targets.last?.distanceMeters == 60)
   }

   // MARK: - Sentinels

   @Test func anIDWithoutThePresenceBitIsSkipped() {
      guard case .threat(let frame) = RideRadarDecoder.classify([0x12, 0x40, 0x14, 0x00]) else {
         Issue.record("Expected a threat frame")
         return
      }

      #expect(frame.targets.isEmpty)
   }

   @Test func aZeroIDIsSkipped() {
      guard case .threat(let frame) = RideRadarDecoder.classify([0x12, 0x00, 0x14, 0x00]) else {
         Issue.record("Expected a threat frame")
         return
      }

      #expect(frame.targets.isEmpty)
   }

   @Test func theStatusMarkerIDIsSkipped() {
      guard case .threat(let frame) = RideRadarDecoder.classify([0x12, 0xFD, 0x14, 0x00]) else {
         Issue.record("Expected a threat frame")
         return
      }

      #expect(frame.targets.isEmpty)
   }

   @Test func theFarDistanceSentinelIsSkipped() {
      guard case .threat(let frame) = RideRadarDecoder.classify([0x12, 0x81, 0xFF, 0x00]) else {
         Issue.record("Expected a threat frame")
         return
      }

      #expect(frame.targets.isEmpty)
   }

   @Test func aSentinelTripletDoesNotTakeItsNeighborsDown() {
      let payload: [UInt8] = [0x12, 0xFD, 0x14, 0x00, 0x83, 0x28, 0x00]

      guard case .threat(let frame) = RideRadarDecoder.classify(payload) else {
         Issue.record("Expected a threat frame")
         return
      }

      #expect(frame.targets.count == 1)
      #expect(frame.targets.first?.trackID == 0x03)
      #expect(frame.targets.first?.distanceMeters == 40)
   }

   // MARK: - Defensive Shapes

   @Test func anEmptyPayloadIsUnknown() {
      #expect(RideRadarDecoder.classify([]) == .unknown)
   }

   @Test func aTruncatedTripletIsUnknown() {
      #expect(RideRadarDecoder.classify([0x12, 0x81]) == .unknown)
      #expect(RideRadarDecoder.classify([0x12, 0x81, 0x1E]) == .unknown)
   }

   @Test func theWrongTypeNibbleIsUnknown() {
      #expect(RideRadarDecoder.classify([0x33]) == .unknown)
      #expect(RideRadarDecoder.classify([0x11, 0x81, 0x1E, 0x00]) == .unknown)
   }

   @Test func aSectorAmplitudePacketIsClassifiedNotDecoded() {
      let classification = RideRadarDecoder.classify([0x06, 0x01, 0x02, 0x03, 0x04, 0x05])
      #expect(classification == .sectorAmplitude)
   }

   @Test func dataPayloadsDecodeLikeByteArrays() {
      let data = Data([0xA2, 0xA0, 0x05, 0x00])

      guard case .threat(let frame) = RideRadarDecoder.classify(data) else {
         Issue.record("Expected a threat frame")
         return
      }

      #expect(frame.targets.first?.distanceMeters == 5)
   }

   // MARK: - Simulator Wire Compatibility

   @Test func everySimulatorStepSpeaksTheRealWireFormat() {
      for scenario in RideRadarSimulator.Scenario.allCases {
         for step in RideRadarSimulator.script(for: scenario) {
            switch RideRadarDecoder.classify(step.payload) {
               case .heartbeat, .threat:
                  continue
               case .sectorAmplitude, .unknown:
                  Issue.record("Undecodable simulator payload in \(scenario): \(step.payload)")
            }
         }
      }
   }

   // MARK: - Speed Scale

   @Test func theSpeedByteIsIgnoredByDefault() {
      #expect(RideRadarSpeedScale.default == .ignored)
      #expect(RideRadarSpeedScale.ignored.metersPerSecond(fromRawByte: 36) == nil)
   }

   @Test func speedScalesInterpretTheRawByte() {
      #expect(RideRadarSpeedScale.metersPerSecond.metersPerSecond(fromRawByte: 10) == 10)
      #expect(RideRadarSpeedScale.kilometersPerHour.metersPerSecond(fromRawByte: 36) == 10)
      #expect(RideRadarSpeedScale.antQuantized.metersPerSecond(fromRawByte: 2) == 6.08)
   }
}
