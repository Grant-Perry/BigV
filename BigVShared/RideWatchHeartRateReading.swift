//
//  RideWatchHeartRateReading.swift
//  BigVShared
//

import Foundation

/// One heart rate sample measured on the wrist, on its way to the phone.
///
/// Carries its own measurement time because the wrist is the sensor and the
/// phone is the display: a reading that crossed a slow link must not be shown
/// as current.
nonisolated struct RideWatchHeartRateReading: Sendable, Equatable {

   let beatsPerMinute: Double
   let measuredAt: Date

   // MARK: - Initialization

   init(beatsPerMinute: Double, measuredAt: Date = .now) {
      self.beatsPerMinute = beatsPerMinute
      self.measuredAt = measuredAt
   }

   // MARK: - Plausibility

   /// Anything outside this band is sensor noise rather than a rider.
   static let plausibleRange: ClosedRange<Double> = 25...240

   var isPlausible: Bool { Self.plausibleRange.contains(beatsPerMinute) }

   // MARK: - Freshness

   /// Whether this reading is recent enough to present as the rider's pulse.
   ///
   /// A slow link, or a payload that waited out a spell of unreachability, must
   /// not leave a minute-old beat frozen on the dashboard.
   func isFresh(at instant: Date = .now, within window: TimeInterval = 10) -> Bool {
      abs(instant.timeIntervalSince(measuredAt)) <= window
   }

   // MARK: - Wire Format

   private enum Key {
      static let beatsPerMinute = "beatsPerMinute"
      static let measuredAt = "measuredAt"
   }

   var body: [String: Any] {
      [
         Key.beatsPerMinute: beatsPerMinute,
         Key.measuredAt: measuredAt.timeIntervalSince1970
      ]
   }

   init?(body: [String: Any]) {
      guard let beatsPerMinute = body[Key.beatsPerMinute] as? Double,
            let measuredAt = body[Key.measuredAt] as? Double
      else { return nil }

      self.beatsPerMinute = beatsPerMinute
      self.measuredAt = Date(timeIntervalSince1970: measuredAt)
   }
}
