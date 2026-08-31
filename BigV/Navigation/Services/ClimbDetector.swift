//
//  ClimbDetector.swift
//  BigV
//

import Foundation

/// Finds the climbs in an elevation profile, by Garmin's rules.
///
/// A climb is at least 500 m long at an average of at least 3%, scored as
/// grade (%) × length (m) and categorized on the Edge thresholds. Pure math
/// with no framework side effects, like `RouteGuidanceEngine`: the same
/// profile always yields the same climbs, at plan time and in a test.
///
/// Real roads breathe — a hairpin flattens, a col dips through a saddle — so
/// rising runs separated by a short, shallow descent are merged before the
/// gate is applied. Without that, one false flat splits an hors-catégorie
/// climb into two Cat 2s that never happened.
nonisolated enum ClimbDetector {

   // MARK: - Configuration

   struct Configuration: Sendable {

      /// Minimum climb length in meters. Garmin's gate.
      var minimumLength: Double = 500

      /// Minimum average grade in percent. Garmin's gate.
      var minimumAverageGrade: Double = 3

      /// Minimum grade × length score. 500 m at 3% scores exactly 1 500, so
      /// this floor only removes efforts the gate already disqualifies.
      var minimumScore: Double = 1_500

      /// A descent inside a climb no longer than this does not end it.
      var interruptionMaxLength: Double = 300

      /// Nor does one that gives back no more altitude than this.
      var interruptionMaxDrop: Double = 10

      static let `default` = Configuration()
   }

   // MARK: - Detection

   /// Every climb in the profile, in route order.
   static func climbs(
      in profile: [RouteElevationSample],
      configuration: Configuration = .default
   ) -> [PlannedClimb] {
      let rises = mergedRises(in: profile, configuration: configuration)

      var climbs: [PlannedClimb] = []
      for rise in rises {
         let length = rise.end.distanceAlongRoute - rise.start.distanceAlongRoute
         guard length >= configuration.minimumLength else { continue }

         let ascent = rise.end.altitude - rise.start.altitude
         let averageGrade = (ascent / length) * 100
         guard averageGrade >= configuration.minimumAverageGrade else { continue }

         let score = averageGrade * length
         guard score > configuration.minimumScore,
               let category = ClimbCategory(score: score)
         else { continue }

         climbs.append(
            PlannedClimb(
               id: climbs.count,
               startDistance: rise.start.distanceAlongRoute,
               endDistance: rise.end.distanceAlongRoute,
               ascent: ascent,
               averageGrade: averageGrade,
               category: category
            )
         )
      }

      return climbs
   }

   // MARK: - Rises

   private struct Rise {
      var start: RouteElevationSample
      var end: RouteElevationSample
   }

   /// Maximal rising runs, with tolerable interruptions folded in.
   ///
   /// A run opens at a local minimum and extends while altitude rises. Descent
   /// is measured from the highest point reached so far — not from the previous
   /// sample — so a long shallow give-back closes the run just as surely as one
   /// steep step down. A dip inside the tolerances keeps the run alive through
   /// the saddle.
   private static func mergedRises(
      in profile: [RouteElevationSample],
      configuration: Configuration
   ) -> [Rise] {
      guard let first = profile.first, profile.count > 1 else { return [] }

      var rises: [Rise] = []
      var base = first
      var peak = first

      for sample in profile.dropFirst() {
         if sample.altitude > peak.altitude {
            peak = sample
            continue
         }

         // Flat or falling. A flat never advances the peak — otherwise a
         // plateau after the crest would stretch the climb along it.
         let drop = peak.altitude - sample.altitude
         let run = sample.distanceAlongRoute - peak.distanceAlongRoute

         if drop > configuration.interruptionMaxDrop || run > configuration.interruptionMaxLength {
            // The descent is real. Close the run at its peak and start
            // looking for the next base from here.
            if peak.altitude > base.altitude {
               rises.append(Rise(start: base, end: peak))
            }
            base = sample
            peak = sample
         } else if sample.altitude <= base.altitude {
            // Never rose to begin with; the true base keeps sliding along a
            // valley floor or down a descent, so a climb starts at its foot
            // rather than at the start of the flat that led there.
            base = sample
            peak = sample
         }
      }

      if peak.altitude > base.altitude {
         rises.append(Rise(start: base, end: peak))
      }

      return rises
   }
}
