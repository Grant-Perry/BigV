//
//  LiveClimbDetector.swift
//  BigV
//

import Foundation

/// Recognizes the climb a rider is on from telemetry alone — no route, no map.
///
/// Freeride's whole contract is honesty: with no elevation profile ahead there
/// is no "remaining", so this reports the climb *so far* and nothing else.
/// Same 500 m / 3% gate as `ClimbDetector`, applied online: a candidate opens
/// at a local minimum, survives dips inside the same tolerances, and closes
/// when the descent becomes real — which is also the moment a climb split can
/// be cut.
///
/// Pure math with no framework side effects, so the gate and the close rule
/// are reachable from a synchronous test.
struct LiveClimbDetector {

   // MARK: - Configuration

   struct Configuration: Sendable {

      /// Minimum length in meters before the effort counts as a climb.
      var minimumLength: Double = 500

      /// Minimum average grade in percent.
      var minimumAverageGrade: Double = 3

      /// A descent that gives back more altitude than this ends the climb.
      var endDrop: Double = 10

      /// So does one that runs longer than this without a new high.
      var endRun: Double = 300

      static let `default` = Configuration()
   }

   // MARK: - Status

   /// The climb underway right now. All zeros while the road is flat.
   struct Status: Sendable, Equatable {

      var isClimbing = false

      /// Meters of road since the climb's base.
      var distanceSoFar: Double = 0

      /// Net meters gained since the base.
      var ascentSoFar: Double = 0

      /// Average grade since the base, as a percentage.
      var averageGrade: Double = 0

      static let idle = Status()
   }

   /// A climb that just ended, reported once at the moment the descent
   /// became real. This is the freeride climb-split trigger.
   struct CompletedClimb: Sendable, Equatable {

      let startDistance: Double
      let endDistance: Double
      let ascent: Double
      let averageGrade: Double

      /// When the rider left the base and when they crested — the crest, not
      /// the later moment the descent confirmed the climb was over.
      let startedAt: Date
      let endedAt: Date

      var length: Double { endDistance - startDistance }

      var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }

      var category: ClimbCategory? {
         ClimbCategory(score: averageGrade * length)
      }
   }

   // MARK: - Published State

   private(set) var status: Status = .idle

   // MARK: - Private State

   private struct Point {
      let distance: Double
      let altitude: Double
      let timestamp: Date
   }

   private var base: Point?
   private var peak: Point?

   private let configuration: Configuration

   // MARK: - Initialization

   init(configuration: Configuration = .default) {
      self.configuration = configuration
   }

   // MARK: - Lifecycle

   mutating func reset() {
      status = .idle
      base = nil
      peak = nil
   }

   // MARK: - Ingestion

   /// Folds one gated altitude reading into the climb state.
   ///
   /// Returns the climb that just finished when this sample is the one that
   /// ended it, and `nil` every other time. Callers feed only altitudes the
   /// telemetry engine already trusted; this applies no accuracy gate of its own.
   mutating func ingest(
      distance: Double,
      altitude: Double,
      timestamp: Date
   ) -> CompletedClimb? {
      let point = Point(distance: distance, altitude: altitude, timestamp: timestamp)

      guard let anchoredBase = base, let highest = peak else {
         base = point
         peak = point
         return nil
      }

      var completed: CompletedClimb?

      if altitude >= highest.altitude {
         peak = point
      } else {
         let drop = highest.altitude - altitude
         let run = distance - highest.distance

         if drop > configuration.endDrop || run > configuration.endRun {
            // The descent is real; the climb — if it was one — ended at the peak.
            completed = climb(from: anchoredBase, to: highest)
            base = point
            peak = point
         } else if altitude < anchoredBase.altitude {
            // Never rose to begin with; the true base keeps sliding down.
            base = point
            peak = point
         }
      }

      refreshStatus(at: point)
      return completed
   }

   // MARK: - Gate

   private func meetsGate(length: Double, grade: Double) -> Bool {
      length >= configuration.minimumLength && grade >= configuration.minimumAverageGrade
   }

   private func climb(from base: Point, to peak: Point) -> CompletedClimb? {
      let length = peak.distance - base.distance
      guard length > 0 else { return nil }

      let ascent = peak.altitude - base.altitude
      let grade = (ascent / length) * 100
      guard meetsGate(length: length, grade: grade) else { return nil }

      return CompletedClimb(
         startDistance: base.distance,
         endDistance: peak.distance,
         ascent: ascent,
         averageGrade: grade,
         startedAt: base.timestamp,
         endedAt: peak.timestamp
      )
   }

   /// Climb-so-far is measured to where the rider *is*, not to the peak — a
   /// rider coasting a tolerated dip should see the dip in their numbers.
   private mutating func refreshStatus(at point: Point) {
      guard let anchoredBase = base else {
         status = .idle
         return
      }

      let length = point.distance - anchoredBase.distance
      let ascent = point.altitude - anchoredBase.altitude
      let grade = length > 0 ? (ascent / length) * 100 : 0

      guard meetsGate(length: length, grade: grade) else {
         status = .idle
         return
      }

      status = Status(
         isClimbing: true,
         distanceSoFar: length,
         ascentSoFar: ascent,
         averageGrade: grade
      )
   }
}
