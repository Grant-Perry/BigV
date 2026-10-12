//
//  RideTelemetryEngine+Types.swift
//  BigV
//

import Foundation

/// The engine's tuning and its vocabulary: what a sample can turn into, and
/// what a ride carries back after an interruption. Kept apart from the math
/// so the main file reads as one pipeline.
extension RideTelemetryEngine {

   // MARK: - Configuration

   struct Configuration: Sendable {

      /// Accuracy required to declare an initial fix. Loose on purpose: the
      /// first lock just has to start the ride. Recording still uses
      /// `maxHorizontalAccuracy` for position and `coarseHorizontalAccuracy`
      /// for speed.
      var fixAcquisitionAccuracy: Double = 65

      /// Accuracy required for a sample's *position* to contribute once
      /// recording: distance from displacement, altitude, the route.
      var maxHorizontalAccuracy: Double = 20

      /// Accuracy up to which a sample still drives speed and moving time.
      /// With a satellite-measured speed the fix drives speed directly —
      /// Doppler is independent of position error, a fix placed 40 m off
      /// still knows the bike is doing 4.5 m/s — and distance integrates it.
      /// Without one, `CoarseGeometry` reads speed out of displacement. The
      /// first minute after START under cloud, in a case, under trees, on a
      /// street thick with Wi-Fi, is exactly this band — the alternative is
      /// a ticking clock over 0.0 mph.
      var coarseHorizontalAccuracy: Double = 65

      /// Least displacement between two loose fixes that counts as ground
      /// covered, however tight they claim to be. The working bar is the sum
      /// of both fixes' accuracy, so two 40 m fixes need 80 m between them.
      var coarseDisplacementFloor: Double = 30

      /// How long displacement may accumulate against one loose anchor before
      /// the anchor slides forward. Long enough for 10 mph to clear two 45 m
      /// circles (≈ 20 s); short enough that 0.5 m/s of drift never does.
      var coarseWindowDuration: TimeInterval = 30

      /// Displacement from the distance anchor that outweighs a reported
      /// standstill. Core Location can hold `speed` at 0 for a few samples
      /// after a stop while the position is plainly advancing; past this
      /// (or twice the fix accuracy, whichever is larger) geometry wins.
      var standstillOverrideDisplacement: Double = 10

      /// Vertical accuracy required before altitude is trusted.
      var maxVerticalAccuracy: Double = 12

      /// Anything faster is a GPS jump, not a bicycle. 26.8 m/s is 60 mph.
      var maxPlausibleSpeed: Double = 26.8

      /// Speed at or above which the rider counts as moving. 0.9 m/s is 2 mph.
      var movingSpeedThreshold: Double = 0.9

      var speedSmoothingFactor: Double = 0.35
      var altitudeSmoothingFactor: Double = 0.2

      /// How far a new geometric pace pulls the displayed speed toward it.
      /// Each pace is already an average over one clear, so this is lighter
      /// than `speedSmoothingFactor`'s per-second blend.
      var geometricSpeedSmoothingFactor: Double = 0.5

      /// Largest fraction the displayed speed may move between two geometric
      /// paces. Jitter can stretch one clear and squeeze the next by half;
      /// the hero must walk between them, not jump.
      var maxGeometricSpeedStep: Double = 0.5

      /// Hard ceiling on any speed read from position alone, about 27 mph.
      /// A loose position can fake a faster pace than a rider sustains on
      /// the flat; satellite speed is the only source trusted above this.
      var maxGeometricSpeed: Double = 12

      /// Altitude must change by this much before it counts as gain or loss.
      var elevationHysteresis: Double = 1.5

      /// Minimum run required before grade is meaningful.
      var gradeWindowDistance: Double = 40
      var maxGradeMagnitude: Double = 25

      /// Seconds of altitude history behind the VAM figure. Thirty seconds is
      /// the convention the number is defined by — long enough to ride out GPS
      /// altitude wobble, short enough to answer "how fast am I climbing now".
      var verticalSpeedWindow: TimeInterval = 30

      /// A larger gap between samples is treated as a signal dropout.
      var maxSampleGap: TimeInterval = 10

      static let `default` = Configuration()
   }

   // MARK: - Sample Outcomes

   enum Rejection: String, Sendable, Equatable {
      case invalidAccuracy
      case poorAccuracy
      case staleTimestamp
      case implausibleJump
   }

   enum Outcome: Sendable, Equatable {
      /// First usable fix of the ride.
      case acquiredFix

      /// Signal returned after a dropout; accumulators re-anchored.
      case reseeded

      case accepted

      /// Position too loose to measure sample to sample. Speed came from the
      /// satellite speed when the fix carried one, else from displacement
      /// over a window; altitude and the precise anchor did not move.
      case acceptedCoarse

      case rejected(Rejection)

      var isAccepted: Bool {
         switch self {
            case .accepted, .acceptedCoarse: true
            case .acquiredFix, .reseeded, .rejected: false
         }
      }
   }

   // MARK: - Restored Totals

   /// Totals carried over from a ride the app was killed in the middle of.
   struct RestoredTotals: Sendable, Equatable {

      var distance: Double = 0
      var movingTime: TimeInterval = 0
      var maximumSpeed: Double = 0
      var elevationGain: Double = 0
      var elevationLoss: Double = 0
      var altitude: Double?
      var acceptedSampleCount: Int = 0
   }
}
