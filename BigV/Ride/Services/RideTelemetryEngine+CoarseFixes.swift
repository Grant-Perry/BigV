//
//  RideTelemetryEngine+CoarseFixes.swift
//  BigV
//

import CoreLocation
import Foundation

/// Everything the engine knows about fixes that are too loose to measure
/// sample to sample: which ones are still worth having, how far apart two of
/// them may legitimately land, and how to read speed out of position alone
/// when there is no satellite speed to lean on.
///
/// The first minute after START under cloud, in a case, under trees is this
/// band — and so is a residential street dense with Wi-Fi, where Core
/// Location will happily place the bike to 40 m from access points for as
/// long as GPS takes to lock. The bike display beside the phone reads 19 mph
/// the whole time; the cockpit must not read 0.0.
extension RideTelemetryEngine {

   // MARK: - Gating

   /// A loose fix is still worth having up to `coarseHorizontalAccuracy`.
   /// With a satellite speed it drives speed directly; without one, its
   /// position feeds `CoarseGeometry`.
   func isUsableCoarseSample(_ location: CLLocation) -> Bool {
      location.horizontalAccuracy <= configuration.coarseHorizontalAccuracy
   }

   /// Whether Core Location measured this fix's speed rather than leaving it
   /// at -1. Wi-Fi and cell fixes never carry one.
   func hasReportedSpeed(_ location: CLLocation) -> Bool {
      location.speedAccuracy >= 0 && location.speed >= 0
   }

   /// Whether the ground covered since the last accepted sample is a bicycle
   /// and not a GPS jump. Position jitter on a loose fix can look like a jump
   /// between two consecutive samples, so coarse pairs get the sum of their
   /// error circles on top of the speed cap.
   func isPlausibleMove(
      _ travelled: Double,
      over interval: TimeInterval,
      from previous: CLLocation,
      to location: CLLocation
   ) -> Bool {
      let allowance = configuration.maxPlausibleSpeed * interval
      let jitter = max(0, previous.horizontalAccuracy - configuration.maxHorizontalAccuracy)
         + max(0, location.horizontalAccuracy - configuration.maxHorizontalAccuracy)
      return travelled <= allowance + jitter
   }

   /// Displacement below this is the fix wobbling, not the bike moving.
   func noiseFloor(for location: CLLocation) -> Double {
      min(6, max(1.5, location.horizontalAccuracy * 0.5))
   }

   // MARK: - Standstill Override

   /// Speed from displacement since the anchor, when that displacement is too
   /// large to be jitter and the time it took makes it a moving bicycle.
   ///
   /// Only a precise fix measured against a precise anchor gets a say; coarse
   /// geometry belongs to `CoarseGeometry`.
   func standstillOverride(for location: CLLocation) -> Double? {
      guard let anchor = distanceAnchor, !anchorIsCoarse else { return nil }

      let displacement = location.distance(from: anchor)
      let elapsed = location.timestamp.timeIntervalSince(anchor.timestamp)
      let floor = max(
         2 * max(location.horizontalAccuracy, anchor.horizontalAccuracy),
         configuration.standstillOverrideDisplacement
      )

      guard elapsed > 0, displacement >= floor else { return nil }

      let geometric = displacement / elapsed
      guard geometric >= configuration.movingSpeedThreshold,
            geometric <= configuration.maxPlausibleSpeed
      else { return nil }

      return geometric
   }

   // MARK: - Coarse Geometry

   /// Speed and distance from position alone, for loose fixes with no
   /// satellite speed.
   ///
   /// One loose fix says nothing: its circle is wider than a second of riding.
   /// Two of them far enough apart do — once the straight line between them is
   /// longer than both error circles combined, the bike covered that ground.
   /// So every fix is measured against an anchor; when the displacement beats
   /// the combined accuracy at a bicycle-plausible pace, speed is that
   /// displacement over that time, the distance is banked, and the anchor
   /// moves up. Until then the last speed is held for as long as it would have
   /// taken to clear the threshold at that pace, and then it is zero — not
   /// stale, zero: the honest reading for a position that is not advancing.
   ///
   /// Stationary jitter never clears: it would have to wander further than
   /// both error circles in a straight line. Slow drift never clears: a
   /// 30-second window caps how long displacement may accumulate before the
   /// anchor slides forward, so 0.5 m/s makes 15 m against an 80 m bar.
   ///
   /// Only distance that cleared the bar is ever banked. The tail between the
   /// last clear and the next precise fix is lost rather than guessed.
   struct CoarseGeometry: Sendable {

      enum Verdict: Sendable, Equatable {
         /// Displacement cleared the bar. Speed is the average over it.
         case moving(speed: Double, displacement: Double)

         /// Not yet cleared, but the last pace is still credible.
         case holding

         /// The position is not advancing.
         case stopped
      }

      private var anchor: CLLocation?

      /// Fixes since the anchor, oldest first — candidates to become the
      /// anchor when it slides forward.
      private var window: [CLLocation] = []

      private var heldSpeed: Double = 0
      private var heldThreshold: Double = 0

      /// Longest the hold may last regardless of pace, so a jitter-inflated
      /// pace cannot hold a speed on screen at a standstill for a minute.
      private static let maximumHold: TimeInterval = 30

      mutating func reset() {
         anchor = nil
         window.removeAll()
         heldSpeed = 0
         heldThreshold = 0
      }

      /// Starts measuring from a known loose position, such as the seed.
      mutating func anchor(at location: CLLocation) {
         reset()
         anchor = location
      }

      /// Measures one loose, speed-less fix against the anchor.
      mutating func ingest(_ location: CLLocation, configuration: Configuration) -> Verdict {
         guard let anchor else {
            self.anchor = location
            return .stopped
         }

         let displacement = location.distance(from: anchor)
         let elapsed = location.timestamp.timeIntervalSince(anchor.timestamp)
         let threshold = max(
            anchor.horizontalAccuracy + location.horizontalAccuracy,
            configuration.coarseDisplacementFloor
         )

         if elapsed > 0, displacement >= threshold {
            let pace = displacement / elapsed
            if pace >= configuration.movingSpeedThreshold, pace <= configuration.maxPlausibleSpeed {
               self.anchor = location
               window.removeAll()
               heldSpeed = pace
               heldThreshold = threshold
               return .moving(speed: pace, displacement: displacement)
            }
         }

         window.append(location)

         if heldSpeed > 0 {
            // At the held pace the bar would have been cleared in
            // threshold / speed seconds; half again covers jitter eating
            // into the displacement. Past that, the bike has slowed or stopped.
            let holdLimit = min(Self.maximumHold, 1.5 * heldThreshold / heldSpeed)
            if elapsed <= holdLimit {
               return .holding
            }
            heldSpeed = 0
            heldThreshold = 0
         }

         slideAnchorIfStale(at: location, configuration: configuration)
         return .stopped
      }

      /// Keeps the anchor within the window so a rider who stops and rolls
      /// off again is measured from a recent position, not from minutes ago
      /// — and so slow drift can never accumulate into a clear.
      private mutating func slideAnchorIfStale(at location: CLLocation, configuration: Configuration) {
         guard let anchor,
               location.timestamp.timeIntervalSince(anchor.timestamp) > configuration.coarseWindowDuration
         else { return }

         let cutoff = location.timestamp.addingTimeInterval(-configuration.coarseWindowDuration)

         if let index = window.firstIndex(where: { $0.timestamp >= cutoff }) {
            self.anchor = window[index]
            window.removeFirst(index + 1)
         } else {
            self.anchor = location
            window.removeAll()
         }
      }
   }
}
