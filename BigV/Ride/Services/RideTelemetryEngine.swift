//
//  RideTelemetryEngine.swift
//  BigV
//

import CoreLocation
import Foundation

/// Turns raw Core Location samples into trustworthy cycling telemetry.
///
/// Pure math with no framework side effects so it can be reasoned about and
/// tested in isolation. Core Location lies at low speeds, in tunnels, and under
/// tree cover; every sample is gated on accuracy, staleness and plausibility
/// before it is allowed to move a number the rider sees.
struct RideTelemetryEngine {

   // MARK: - Configuration

   struct Configuration: Sendable {

      /// Accuracy required to declare an initial fix.
      var fixAcquisitionAccuracy: Double = 30

      /// Accuracy required for a sample to contribute once recording.
      var maxHorizontalAccuracy: Double = 20

      /// Vertical accuracy required before altitude is trusted.
      var maxVerticalAccuracy: Double = 12

      /// Anything faster is a GPS jump, not a bicycle. 26.8 m/s is 60 mph.
      var maxPlausibleSpeed: Double = 26.8

      /// Speed at or above which the rider counts as moving. 0.9 m/s is 2 mph.
      var movingSpeedThreshold: Double = 0.9

      var speedSmoothingFactor: Double = 0.35
      var altitudeSmoothingFactor: Double = 0.2

      /// Altitude must change by this much before it counts as gain or loss.
      var elevationHysteresis: Double = 1.5

      /// Minimum run required before grade is meaningful.
      var gradeWindowDistance: Double = 40
      var maxGradeMagnitude: Double = 25

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
      case rejected(Rejection)
   }

   // MARK: - Published Telemetry

   private(set) var speed: Double = 0
   private(set) var maximumSpeed: Double = 0
   private(set) var distance: Double = 0
   private(set) var movingTime: TimeInterval = 0
   private(set) var stoppedTime: TimeInterval = 0
   private(set) var altitude: Double?
   private(set) var elevationGain: Double = 0
   private(set) var elevationLoss: Double = 0
   private(set) var grade: Double = 0
   private(set) var course: Double = -1
   private(set) var horizontalAccuracy: Double?
   private(set) var hasFix = false
   private(set) var isMoving = false
   private(set) var acceptedSampleCount = 0
   private(set) var rejectedSampleCount = 0

   /// Average over moving time, which is what riders expect from a bike computer.
   var averageSpeed: Double {
      movingTime > 0 ? distance / movingTime : 0
   }

   // MARK: - Private State

   private let configuration: Configuration
   private var lastAcceptedLocation: CLLocation?
   private var distanceAnchor: CLLocation?
   private var elevationReference: Double?
   private var gradeWindow: [GradePoint] = []

   private struct GradePoint {
      let distance: Double
      let altitude: Double
   }

   // MARK: - Initialization

   init(configuration: Configuration = .default) {
      self.configuration = configuration
   }

   // MARK: - Lifecycle

   mutating func reset() {
      speed = 0
      maximumSpeed = 0
      distance = 0
      movingTime = 0
      stoppedTime = 0
      altitude = nil
      elevationGain = 0
      elevationLoss = 0
      grade = 0
      course = -1
      horizontalAccuracy = nil
      hasFix = false
      isMoving = false
      acceptedSampleCount = 0
      rejectedSampleCount = 0
      lastAcceptedLocation = nil
      distanceAnchor = nil
      elevationReference = nil
      gradeWindow.removeAll()
   }

   /// Zeroes the displayed speed without disturbing totals.
   ///
   /// Used when samples stop arriving, so a stopped rider never sees a stale number.
   mutating func markSpeedStale() {
      speed = 0
      isMoving = false
      grade = 0
   }

   // MARK: - Ingestion

   mutating func ingest(_ location: CLLocation) -> Outcome {
      guard location.horizontalAccuracy > 0 else {
         rejectedSampleCount += 1
         return .rejected(.invalidAccuracy)
      }

      horizontalAccuracy = location.horizontalAccuracy

      guard hasFix, let previous = lastAcceptedLocation else {
         guard location.horizontalAccuracy <= configuration.fixAcquisitionAccuracy else {
            rejectedSampleCount += 1
            return .rejected(.poorAccuracy)
         }
         seed(with: location)
         return .acquiredFix
      }

      guard location.horizontalAccuracy <= configuration.maxHorizontalAccuracy else {
         rejectedSampleCount += 1
         return .rejected(.poorAccuracy)
      }

      let interval = location.timestamp.timeIntervalSince(previous.timestamp)

      guard interval > 0.05 else {
         rejectedSampleCount += 1
         return .rejected(.staleTimestamp)
      }

      // A dropout must not become phantom distance or phantom moving time.
      guard interval <= configuration.maxSampleGap else {
         seed(with: location)
         return .reseeded
      }

      let travelled = location.distance(from: previous)

      guard travelled / interval <= configuration.maxPlausibleSpeed else {
         rejectedSampleCount += 1
         return .rejected(.implausibleJump)
      }

      updateSpeed(with: location, travelled: travelled, interval: interval)
      updateTime(interval: interval)
      updateElevation(with: location)
      updateDistance(with: location)
      updateGrade()
      updateCourse(with: location)

      lastAcceptedLocation = location
      acceptedSampleCount += 1
      return .accepted
   }

   // MARK: - Seeding

   private mutating func seed(with location: CLLocation) {
      hasFix = true
      lastAcceptedLocation = location
      distanceAnchor = location

      guard location.verticalAccuracy > 0,
            location.verticalAccuracy <= configuration.maxVerticalAccuracy else { return }

      if altitude == nil {
         altitude = location.altitude
      }
      if elevationReference == nil {
         elevationReference = altitude
      }
   }

   // MARK: - Speed

   private mutating func updateSpeed(with location: CLLocation, travelled: Double, interval: TimeInterval) {
      let reported = location.speedAccuracy >= 0 && location.speed >= 0
         ? location.speed
         : travelled / interval

      let plausible = min(max(0, reported), configuration.maxPlausibleSpeed)

      speed = speed == 0
         ? plausible
         : speed + (plausible - speed) * configuration.speedSmoothingFactor

      isMoving = speed >= configuration.movingSpeedThreshold

      // Maximum comes from the smoothed value so a single bad sample cannot
      // permanently inflate the ride's headline number.
      if isMoving {
         maximumSpeed = max(maximumSpeed, speed)
      }
   }

   // MARK: - Time

   private mutating func updateTime(interval: TimeInterval) {
      if isMoving {
         movingTime += interval
      } else {
         stoppedTime += interval
      }
   }

   // MARK: - Distance

   private mutating func updateDistance(with location: CLLocation) {
      guard let anchor = distanceAnchor else {
         distanceAnchor = location
         return
      }

      let travelled = location.distance(from: anchor)
      let noiseFloor = min(6, max(1.5, location.horizontalAccuracy * 0.5))

      // The anchor only advances when real ground was covered, so slow riding
      // accumulates instead of being filtered away sample by sample.
      guard isMoving, travelled >= noiseFloor else { return }

      distance += travelled
      distanceAnchor = location
      appendGradePoint()
   }

   // MARK: - Elevation

   private mutating func updateElevation(with location: CLLocation) {
      guard location.verticalAccuracy > 0,
            location.verticalAccuracy <= configuration.maxVerticalAccuracy else { return }

      let smoothed: Double
      if let current = altitude {
         smoothed = current + (location.altitude - current) * configuration.altitudeSmoothingFactor
      } else {
         smoothed = location.altitude
      }
      altitude = smoothed

      guard let reference = elevationReference else {
         elevationReference = smoothed
         return
      }

      let delta = smoothed - reference

      if delta >= configuration.elevationHysteresis {
         elevationGain += delta
         elevationReference = smoothed
      } else if delta <= -configuration.elevationHysteresis {
         elevationLoss += abs(delta)
         elevationReference = smoothed
      }
   }

   // MARK: - Grade

   private mutating func appendGradePoint() {
      guard let altitude else { return }

      gradeWindow.append(GradePoint(distance: distance, altitude: altitude))

      let cutoff = distance - configuration.gradeWindowDistance * 3
      if let staleIndex = gradeWindow.lastIndex(where: { $0.distance < cutoff }), staleIndex > 0 {
         gradeWindow.removeFirst(staleIndex)
      }
   }

   private mutating func updateGrade() {
      guard isMoving else {
         grade = 0
         return
      }

      guard let latest = gradeWindow.last,
            let baseline = gradeWindow.last(where: {
               latest.distance - $0.distance >= configuration.gradeWindowDistance
            })
      else { return }

      let run = latest.distance - baseline.distance
      guard run > 0 else { return }

      let percent = ((latest.altitude - baseline.altitude) / run) * 100
      grade = min(max(percent, -configuration.maxGradeMagnitude), configuration.maxGradeMagnitude)
   }

   // MARK: - Course

   private mutating func updateCourse(with location: CLLocation) {
      guard location.course >= 0, location.courseAccuracy >= 0 else { return }
      course = location.course
   }
}
