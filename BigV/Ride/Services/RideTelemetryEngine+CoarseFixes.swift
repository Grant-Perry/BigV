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

   /// The displayed speed after one more geometric pace lands.
   ///
   /// From a standstill the pace is taken whole; there is nothing to blend
   /// with and the rider has waited long enough. Otherwise the pace pulls the
   /// reading toward it by `geometricSpeedSmoothingFactor`, and the move is
   /// capped at `maxGeometricSpeedStep` of the current reading either way.
   func dampedGeometricSpeed(toward pace: Double) -> Double {
      guard speed > 0 else { return pace }

      let blended = speed + (pace - speed) * configuration.geometricSpeedSmoothingFactor
      let step = speed * configuration.maxGeometricSpeedStep
      return min(max(blended, speed - step), speed + step)
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
   /// Placing the anchor, and a first clear still waiting on a second, are
   /// not that stop. They leave whatever speed is already on screen.
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
         /// Displacement cleared the bar twice in a row. Speed is the average
         /// over it, and `elapsed` is how long that ground took.
         case moving(speed: Double, displacement: Double, elapsed: TimeInterval)

         /// Not yet cleared, but the last pace is still credible.
         case holding

         /// No pace has been confirmed from this window. The anchor was just
         /// placed, a first clear is waiting on a second, or the bar has not
         /// been cleared and nothing is being held. Not a stop, and not
         /// distance the engine may bank.
         case unconfirmed

         /// A held pace ran out because the position stopped advancing.
         /// The displayed speed may fall to zero. No distance was banked.
         case stopped
      }

      private var anchor: CLLocation?

      /// Fixes since the anchor, oldest first — candidates to become the
      /// anchor when it slides forward.
      private var window: [CLLocation] = []

      private var heldSpeed: Double = 0
      private var heldThreshold: Double = 0

      /// When the window first cleared. One clear only moves the anchor — a
      /// 100 m lurch of a Wi-Fi position looks exactly like a 22 mph burst —
      /// and a second clear within the window confirms the bike is going
      /// somewhere. Nil while nothing is pending.
      private var firstClearAt: Date?

      /// Longest the hold may last regardless of pace, so a jitter-inflated
      /// pace cannot hold a speed on screen at a standstill for a minute.
      private static let maximumHold: TimeInterval = 30

      /// How many nominal clear times the hold survives. Jitter can push the
      /// position back by as much as both error circles, which doubles the
      /// ground the bike has to cover before the next clear lands, and the
      /// pace the hold is timed on may itself be half again too high. Short
      /// of this the hero flashes zero between two honest clears.
      private static let holdMargin: Double = 3

      mutating func reset() {
         anchor = nil
         window.removeAll()
         heldSpeed = 0
         heldThreshold = 0
         firstClearAt = nil
      }

      /// The pace the hold is timed against. The engine calls this with the
      /// damped reading after a clear: a single stretched pace must not
      /// shorten the window so much that the next honest clear lands late and
      /// the hero flashes zero in between.
      mutating func holdPace(_ speed: Double) {
         guard heldSpeed > 0 else { return }
         heldSpeed = speed
      }

      /// Measures one loose, speed-less fix against the anchor.
      mutating func ingest(_ location: CLLocation, configuration: Configuration) -> Verdict {
         guard let anchor else {
            self.anchor = location
            return .unconfirmed
         }

         let displacement = location.distance(from: anchor)
         let elapsed = location.timestamp.timeIntervalSince(anchor.timestamp)
         let threshold = max(
            anchor.horizontalAccuracy + location.horizontalAccuracy,
            configuration.coarseDisplacementFloor
         )

         let holdLimit = heldSpeed > 0
            ? min(Self.maximumHold, Self.holdMargin * heldThreshold / heldSpeed)
            : 0

         if elapsed > 0, displacement >= threshold {
            let pace = displacement / elapsed
            if pace >= configuration.movingSpeedThreshold, pace <= configuration.maxPlausibleSpeed {
               self.anchor = location
               window.removeAll()

               let isContinuing = heldSpeed > 0 && elapsed <= holdLimit
               let isConfirming = firstClearAt.map {
                  location.timestamp.timeIntervalSince($0) <= configuration.coarseWindowDuration
               } ?? false

               // The first clear of a run only sets the anchor. It is not a
               // stop and it is not a pace — one lurch must not publish.
               guard isContinuing || isConfirming else {
                  firstClearAt = location.timestamp
                  heldSpeed = 0
                  heldThreshold = 0
                  return .unconfirmed
               }

               firstClearAt = nil
               heldSpeed = pace
               heldThreshold = threshold
               return .moving(speed: pace, displacement: displacement, elapsed: elapsed)
            }
         }

         window.append(location)

         if heldSpeed > 0 {
            // At the held pace the bar would have been cleared in
            // threshold / speed seconds; the margin covers jitter eating
            // into the displacement. Past that, the bike has slowed or stopped.
            if elapsed <= holdLimit {
               return .holding
            }
            heldSpeed = 0
            heldThreshold = 0
            firstClearAt = nil
            slideAnchorIfStale(at: location, configuration: configuration)
            return .stopped
         }

         // No pace in this window yet. Failing the bar is not a stop — a
         // precise speed the rider already had stays up until a hold of a
         // published pace actually runs out.
         slideAnchorIfStale(at: location, configuration: configuration)
         return .unconfirmed
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
