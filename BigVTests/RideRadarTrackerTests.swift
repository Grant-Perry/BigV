//
//  RideRadarTrackerTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

struct RideRadarTrackerTests {

   private let reference = Date(timeIntervalSince1970: 1_700_000_000)

   // MARK: - Helpers

   private func frame(
      cars: [(id: UInt8, distance: Double)],
      at receivedAt: Date
   ) -> RideRadarFrame {
      RideRadarFrame(
         sequence: 0,
         targets: cars.map {
            RideRadarTargetReading(trackID: $0.id, distanceMeters: $0.distance, rawSpeedByte: 0)
         },
         receivedAt: receivedAt
      )
   }

   private func heartbeat(at receivedAt: Date) -> RideRadarFrame {
      RideRadarFrame(sequence: 0, targets: [], receivedAt: receivedAt)
   }

   /// Drives one car from 100 m at a constant 10 m/s, one frame per second.
   /// Returns the tracker and every event in order.
   private func constantApproach(
      frames: Int,
      id: UInt8 = 0x21
   ) -> (tracker: RideRadarTracker, events: [RideRadarTracker.Event]) {
      var tracker = RideRadarTracker()
      var events: [RideRadarTracker.Event] = []

      for index in 0..<frames {
         let now = reference.addingTimeInterval(Double(index))
         let distance = 100.0 - Double(index) * 10
         events.append(contentsOf: tracker.ingest(frame(cars: [(id, distance)], at: now), at: now))
      }

      return (tracker, events)
   }

   // MARK: - Entry

   @Test func aNewVehicleEntersAsAnApproachingThreat() {
      var tracker = RideRadarTracker()

      let events = tracker.ingest(frame(cars: [(0x21, 120)], at: reference), at: reference)

      #expect(events == [.threatEntered(trackID: 0x21)])
      #expect(tracker.tracks.count == 1)
      #expect(tracker.tracks.first?.tier == .approaching)
      #expect(tracker.aggregateTier == .approaching)
   }

   @Test func reappearingVehiclesDoNotReenter() {
      var tracker = RideRadarTracker()

      _ = tracker.ingest(frame(cars: [(0x21, 120)], at: reference), at: reference)
      let second = reference.addingTimeInterval(0.15)
      let events = tracker.ingest(frame(cars: [(0x21, 118)], at: second), at: second)

      #expect(!events.contains(.threatEntered(trackID: 0x21)))
      #expect(tracker.tracks.count == 1)
   }

   @Test func theBoardHoldsAtMostEightTracks() {
      var tracker = RideRadarTracker()

      let first = frame(cars: (1...6).map { (UInt8($0), Double(100 + $0)) }, at: reference)
      _ = tracker.ingest(first, at: reference)

      let second = reference.addingTimeInterval(0.15)
      let more = frame(cars: (7...9).map { (UInt8($0), Double(100 + $0)) }, at: second)
      _ = tracker.ingest(more, at: second)

      #expect(tracker.tracks.count == 8)
   }

   // MARK: - Derived Closing Speed

   @Test func closingSpeedIsDerivedFromTheDistanceDerivative() {
      let (tracker, _) = constantApproach(frames: 10)

      guard let track = tracker.tracks.first else {
         Issue.record("Expected a live track")
         return
      }

      // The wire byte was zero the whole way; the smoothed derivative should
      // have converged on the true 10 m/s.
      #expect(track.closingSpeedMetersPerSecond > 9)
      #expect(track.closingSpeedMetersPerSecond < 10.5)
   }

   @Test func aFastApproachEscalatesToHigh() {
      let (tracker, events) = constantApproach(frames: 8)

      #expect(tracker.tracks.first?.tier == .high)
      #expect(events.contains(.tierEscalated(trackID: 0x21, tier: .high)))
   }

   @Test func anImminentContactEscalatesEvenAtModerateSpeed() {
      var tracker = RideRadarTracker()
      var events: [RideRadarTracker.Event] = []

      // Close and closing: time-to-contact crosses the threshold while the
      // smoothed speed is still well under the fast-approach bar.
      for (index, distance) in [40.0, 30, 20, 12].enumerated() {
         let now = reference.addingTimeInterval(Double(index))
         events.append(contentsOf: tracker.ingest(frame(cars: [(0x33, distance)], at: now), at: now))
      }

      guard let track = tracker.tracks.first else {
         Issue.record("Expected a live track")
         return
      }

      #expect(track.tier == .high)
      #expect(track.closingSpeedMetersPerSecond < 8)
      #expect(events.contains(.tierEscalated(trackID: 0x33, tier: .high)))
   }

   // MARK: - Hysteresis

   @Test func aHighThreatDoesNotStrobeAtTheBoundary() {
      var (tracker, _) = constantApproach(frames: 7)
      #expect(tracker.tracks.first?.tier == .high)

      // The car stops gaining. One frame later its smoothed closing speed sits
      // between the exit and entry thresholds — a fresh track there would be
      // amber, but an escalated one must hold red.
      let hold = reference.addingTimeInterval(7)
      _ = tracker.ingest(frame(cars: [(0x21, 40)], at: hold), at: hold)

      guard let track = tracker.tracks.first else {
         Issue.record("Expected a live track")
         return
      }

      #expect(track.closingSpeedMetersPerSecond < 8)
      #expect(track.closingSpeedMetersPerSecond > 6)
      #expect(track.tier == .high)
   }

   @Test func aGenuinelyCalmedThreatDeescalates() {
      var (tracker, _) = constantApproach(frames: 7)

      for offset in [7.0, 8, 9] {
         let now = reference.addingTimeInterval(offset)
         _ = tracker.ingest(frame(cars: [(0x21, 40)], at: now), at: now)
      }

      #expect(tracker.tracks.first?.tier == .approaching)
   }

   // MARK: - Aging and All-Clear

   @Test func aSilentTrackExpiresIntoAPass() {
      var tracker = RideRadarTracker()
      _ = tracker.ingest(frame(cars: [(0x21, 30)], at: reference), at: reference)

      let later = reference.addingTimeInterval(3)
      let events = tracker.expireStaleTracks(at: later)

      #expect(tracker.tracks.isEmpty)
      #expect(tracker.vehiclePassCount == 1)
      #expect(events.count == 2)
      #expect(events.last == .allClear)

      guard case .passCompleted(let pass) = events.first else {
         Issue.record("Expected a completed pass, got \(String(describing: events.first))")
         return
      }
      #expect(pass.trackID == 0x21)
   }

   @Test func heartbeatsAgeTheBoardToo() {
      var tracker = RideRadarTracker()
      _ = tracker.ingest(frame(cars: [(0x21, 30)], at: reference), at: reference)

      let later = reference.addingTimeInterval(3)
      let events = tracker.ingest(heartbeat(at: later), at: later)

      #expect(tracker.tracks.isEmpty)
      #expect(events.contains(.allClear))
   }

   @Test func anEmptyBoardStaysSilent() {
      var tracker = RideRadarTracker()

      let events = tracker.expireStaleTracks(at: reference)

      #expect(events.isEmpty)
   }

   @Test func allClearWaitsForTheLastVehicle() {
      var tracker = RideRadarTracker()
      _ = tracker.ingest(frame(cars: [(0x21, 30), (0x22, 90)], at: reference), at: reference)

      // Only one keeps reporting.
      let second = reference.addingTimeInterval(1.5)
      _ = tracker.ingest(frame(cars: [(0x22, 80)], at: second), at: second)

      let third = reference.addingTimeInterval(2.6)
      let events = tracker.expireStaleTracks(at: third)

      #expect(events.contains { if case .passCompleted = $0 { true } else { false } })
      #expect(!events.contains(.allClear))
      #expect(tracker.tracks.count == 1)
   }

   // MARK: - Pass Aggregation

   @Test func passesCarryTheClosestPointAndPeakSpeed() {
      var (tracker, _) = constantApproach(frames: 10)

      let later = reference.addingTimeInterval(12)
      let events = tracker.expireStaleTracks(at: later)

      guard case .passCompleted(let pass) = events.first else {
         Issue.record("Expected a completed pass")
         return
      }

      #expect(pass.minimumDistanceMeters < 25)
      #expect(pass.maximumClosingSpeedMetersPerSecond > 9)
      #expect(pass.peakTier == .high)
      #expect(tracker.closestPassDistanceMeters == pass.minimumDistanceMeters)
      #expect(tracker.maximumClosingSpeedMetersPerSecond == pass.maximumClosingSpeedMetersPerSecond)
   }

   @Test func distinctVehiclesCountDistinctPasses() {
      var tracker = RideRadarTracker()

      _ = tracker.ingest(frame(cars: [(0x21, 30)], at: reference), at: reference)
      let second = reference.addingTimeInterval(0.5)
      _ = tracker.ingest(frame(cars: [(0x21, 25), (0x22, 90)], at: second), at: second)

      let later = reference.addingTimeInterval(5)
      _ = tracker.expireStaleTracks(at: later)

      #expect(tracker.vehiclePassCount == 2)
   }

   @Test func resetClearsTheRide() {
      var (tracker, _) = constantApproach(frames: 5)
      _ = tracker.expireStaleTracks(at: reference.addingTimeInterval(10))

      tracker.reset()

      #expect(tracker.tracks.isEmpty)
      #expect(tracker.vehiclePassCount == 0)
      #expect(tracker.closestPassDistanceMeters == nil)
      #expect(tracker.maximumClosingSpeedMetersPerSecond == 0)
   }
}
