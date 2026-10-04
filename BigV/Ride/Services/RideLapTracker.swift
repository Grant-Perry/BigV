//
//  RideLapTracker.swift
//  BigV
//

import Foundation

/// Cuts a ride into laps, manually and by distance.
///
/// Pure math with no framework side effects, so auto-lap crossings can be
/// proven in a synchronous test. The session owns one of these, feeds it the
/// telemetry it already publishes, and persists whatever comes back — the
/// tracker never sees storage and storage never sees a threshold.
nonisolated struct RideLapTracker {

   // MARK: - Trigger

   enum Trigger: String, Sendable {
      /// The rider pressed LAP.
      case manual

      /// A distance boundary was crossed.
      case auto

      /// The ride ended with laps on the clock; the remainder becomes one.
      case rideEnd
   }

   // MARK: - Lap

   struct Lap: Sendable, Equatable {

      /// 1-based, the number a rider says out loud.
      let index: Int

      let startDate: Date
      let endDate: Date
      let startDistance: Double
      let endDistance: Double
      let elevationGain: Double
      let trigger: Trigger

      /// Ride-clock seconds the lap covered, paused time excluded.
      let duration: TimeInterval

      var distance: Double { max(0, endDistance - startDistance) }

      var averageSpeed: Double {
         duration > 0 ? distance / duration : 0
      }
   }

   // MARK: - State

   private(set) var completedLapCount = 0

   /// Whether any lap has been cut this ride — what decides if ride end should
   /// close out the remainder as a final lap.
   var hasLaps: Bool { completedLapCount > 0 }

   private var anchorDate: Date?
   private var anchorDistance: Double = 0
   private var anchorElevationGain: Double = 0
   private var anchorElapsed: TimeInterval = 0

   // MARK: - Lifecycle

   /// Anchors lap zero. Called when recording begins.
   mutating func begin(at date: Date) {
      anchorDate = date
      anchorDistance = 0
      anchorElevationGain = 0
      anchorElapsed = 0
      completedLapCount = 0
   }

   mutating func reset() {
      anchorDate = nil
      anchorDistance = 0
      anchorElevationGain = 0
      anchorElapsed = 0
      completedLapCount = 0
   }

   /// Re-anchors onto a ride that was interrupted, from the laps already stored.
   ///
   /// The open lap is whatever came after the last cut, so the anchor is that
   /// cut — or the ride's start when nothing was ever cut. Auto-lap boundaries
   /// then keep falling exactly where they would have.
   mutating func restore(
      completedLapCount: Int,
      anchorDate: Date,
      anchorDistance: Double,
      anchorElevationGain: Double,
      anchorElapsed: TimeInterval? = nil
   ) {
      self.completedLapCount = max(0, completedLapCount)
      self.anchorDate = anchorDate
      self.anchorDistance = max(0, anchorDistance)
      self.anchorElevationGain = max(0, anchorElevationGain)
      self.anchorElapsed = max(0, anchorElapsed ?? 0)
   }

   // MARK: - Manual

   /// Cuts a lap here, wherever here is. `nil` before recording has begun.
   ///
   /// `elapsed` is the ride clock's total at this moment (pauses excluded). When
   /// omitted the lap falls back to wall-clock time between the two dates.
   mutating func cut(
      distance: Double,
      elevationGain: Double,
      at date: Date,
      elapsed: TimeInterval? = nil,
      trigger: Trigger = .manual
   ) -> Lap? {
      guard let startedAt = anchorDate else { return nil }

      let lapDuration = elapsed.map { max(0, $0 - anchorElapsed) }
         ?? max(0, date.timeIntervalSince(startedAt))

      let lap = Lap(
         index: completedLapCount + 1,
         startDate: startedAt,
         endDate: date,
         startDistance: anchorDistance,
         endDistance: distance,
         elevationGain: max(0, elevationGain - anchorElevationGain),
         trigger: trigger,
         duration: lapDuration
      )

      completedLapCount += 1
      anchorDate = date
      anchorDistance = distance
      anchorElevationGain = elevationGain
      anchorElapsed = elapsed ?? (anchorElapsed + lapDuration)

      return lap
   }

   // MARK: - Auto

   /// Every lap the ride's distance has crossed into since the last check.
   ///
   /// The boundary is exact — a 5-mile auto lap ends at 5.00 miles, not at the
   /// GPS sample that noticed — so lap distances read clean on the summary.
   /// Normally returns nothing or one lap; a stalled UI catching up can
   /// legitimately return more.
   mutating func autoLaps(
      distance: Double,
      elevationGain: Double,
      at date: Date,
      elapsed: TimeInterval? = nil,
      every threshold: Double?
   ) -> [Lap] {
      guard anchorDate != nil, let threshold, threshold > 0 else { return [] }

      var laps: [Lap] = []

      while distance >= anchorDistance + threshold {
         guard let lap = cut(
            distance: anchorDistance + threshold,
            elevationGain: elevationGain,
            at: date,
            elapsed: elapsed,
            trigger: .auto
         ) else { break }

         laps.append(lap)
      }

      return laps
   }
}
