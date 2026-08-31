//
//  RideLapTrackerTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

@MainActor
struct RideLapTrackerTests {

   private static let reference = Date(timeIntervalSince1970: 1_000_000)

   private func at(_ seconds: TimeInterval) -> Date {
      Self.reference.addingTimeInterval(seconds)
   }

   // MARK: - Manual

   @Test func aManualCutCarriesTheWindowSinceTheLastAnchor() throws {
      var tracker = RideLapTracker()
      tracker.begin(at: at(0))

      let cutLap = tracker.cut(distance: 5_000, elevationGain: 120, at: at(900), trigger: .manual)
      let lap = try #require(cutLap)

      #expect(lap.index == 1)
      #expect(lap.startDistance == 0)
      #expect(lap.endDistance == 5_000)
      #expect(lap.distance == 5_000)
      #expect(lap.duration == 900)
      #expect(lap.elevationGain == 120)
      #expect(abs(lap.averageSpeed - 5_000 / 900) < 0.01)
      #expect(lap.trigger == .manual)

      // The second lap measures only its own window, not the ride total.
      let secondCut = tracker.cut(distance: 8_000, elevationGain: 150, at: at(1_500))
      let second = try #require(secondCut)
      #expect(second.index == 2)
      #expect(second.startDistance == 5_000)
      #expect(second.distance == 3_000)
      #expect(second.duration == 600)
      #expect(second.elevationGain == 30)
   }

   @Test func aCutBeforeRecordingIsNothing() {
      var tracker = RideLapTracker()
      let cut = tracker.cut(distance: 1_000, elevationGain: 0, at: at(60))
      #expect(cut == nil)
      #expect(!tracker.hasLaps)
   }

   @Test func resetForgetsEverything() {
      var tracker = RideLapTracker()
      tracker.begin(at: at(0))
      _ = tracker.cut(distance: 1_000, elevationGain: 0, at: at(60))

      tracker.reset()
      #expect(!tracker.hasLaps)

      let cut = tracker.cut(distance: 2_000, elevationGain: 0, at: at(120))
      #expect(cut == nil)
   }

   // MARK: - Auto

   @Test func crossingTheThresholdCutsAtTheExactBoundary() throws {
      var tracker = RideLapTracker()
      tracker.begin(at: at(0))

      // Short of the boundary: nothing.
      let early = tracker.autoLaps(distance: 4_900, elevationGain: 40, at: at(800), every: 5_000)
      #expect(early.isEmpty)

      // The GPS sample lands past 5 000 m, but the lap ends exactly on it.
      let laps = tracker.autoLaps(distance: 5_050, elevationGain: 42, at: at(830), every: 5_000)
      let lap = try #require(laps.first)

      #expect(laps.count == 1)
      #expect(lap.endDistance == 5_000)
      #expect(lap.trigger == .auto)

      // The 50 m overshoot belongs to the next lap's window.
      let manualCut = tracker.cut(distance: 5_050, elevationGain: 42, at: at(831))
      let manual = try #require(manualCut)
      #expect(manual.startDistance == 5_000)
      #expect(manual.distance == 50)
   }

   @Test func aLongGapCanCrossSeveralBoundariesAtOnce() {
      var tracker = RideLapTracker()
      tracker.begin(at: at(0))

      // A stalled UI catching up jumps three boundaries in one check.
      let laps = tracker.autoLaps(distance: 15_500, elevationGain: 90, at: at(3_000), every: 5_000)

      #expect(laps.count == 3)
      #expect(laps.map(\.endDistance) == [5_000, 10_000, 15_000])
      #expect(laps.map(\.index) == [1, 2, 3])
   }

   @Test func zeroOrMissingThresholdMeansOff() {
      var tracker = RideLapTracker()
      tracker.begin(at: at(0))

      let off = tracker.autoLaps(distance: 50_000, elevationGain: 0, at: at(600), every: nil)
      let zero = tracker.autoLaps(distance: 50_000, elevationGain: 0, at: at(600), every: 0)
      #expect(off.isEmpty)
      #expect(zero.isEmpty)
      #expect(!tracker.hasLaps)
   }

   @Test func manualAndAutoShareOneNumbering() throws {
      var tracker = RideLapTracker()
      tracker.begin(at: at(0))

      let manualCut = tracker.cut(distance: 2_000, elevationGain: 10, at: at(300))
      #expect(manualCut != nil)
      let auto = tracker.autoLaps(distance: 7_100, elevationGain: 30, at: at(1_000), every: 5_000)

      // Auto boundaries anchor from the manual cut: 2 000 + 5 000 = 7 000.
      #expect(auto.first?.endDistance == 7_000)
      #expect(auto.first?.index == 2)
      #expect(tracker.completedLapCount == 2)
   }
}
