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

   /// Vertical speed in meters/hour — VAM. Signed: negative means descending.
   /// Zero until the altitude window spans its configured seconds.
   private(set) var verticalSpeed: Double = 0
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

   /// Read by the coarse-fix extension; the engine's own file is the only
   /// place that mutates state.
   let configuration: Configuration
   private var lastAcceptedLocation: CLLocation?
   private(set) var distanceAnchor: CLLocation?

   /// Whether the anchor was placed by a coarse sample. The first precise
   /// sample after one re-anchors instead of measuring against a position
   /// that could be tens of metres off.
   private(set) var anchorIsCoarse = false

   /// Speed from position alone while loose fixes carry no satellite speed.
   private var coarseGeometry = CoarseGeometry()

   /// Whether geometry has overruled a reported standstill and is still
   /// carrying speed sample to sample. Released the moment the reported speed
   /// comes back or the position itself stops advancing.
   private var isOverridingStandstill = false
   private var elevationReference: Double?
   private var needsReseed = false
   private var gradeWindow: [GradePoint] = []
   private var verticalWindow: [VerticalPoint] = []

   private struct GradePoint {
      let distance: Double
      let altitude: Double
   }

   private struct VerticalPoint {
      let timestamp: Date
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
      verticalSpeed = 0
      course = -1
      horizontalAccuracy = nil
      hasFix = false
      isMoving = false
      acceptedSampleCount = 0
      rejectedSampleCount = 0
      lastAcceptedLocation = nil
      distanceAnchor = nil
      anchorIsCoarse = false
      isOverridingStandstill = false
      coarseGeometry.reset()
      elevationReference = nil
      needsReseed = false
      gradeWindow.removeAll()
      verticalWindow.removeAll()
   }

   // MARK: - Restore

   /// Reloads a ride's accumulated totals without a position anchor.
   ///
   /// Deliberately leaves `hasFix` false: the next sample seeds the engine as
   /// if it were the ride's first, so the metres the rider covered while the app
   /// was dead never arrive as one phantom straight line. Distance, climbing and
   /// moving time resume from the figures already on disk and grow from there.
   mutating func restore(_ totals: RestoredTotals) {
      reset()

      distance = totals.distance
      movingTime = totals.movingTime
      maximumSpeed = totals.maximumSpeed
      elevationGain = totals.elevationGain
      elevationLoss = totals.elevationLoss
      altitude = totals.altitude
      elevationReference = totals.altitude
      acceptedSampleCount = totals.acceptedSampleCount
   }

   /// Forces the next fix to re-seed instead of integrating from the last
   /// accepted one. A pause, however short, must not bill the rider's movement
   /// during it (or the gap's moving time) as ride distance.
   mutating func invalidateAnchor() {
      guard hasFix else { return }
      needsReseed = true
   }

   /// Zeroes the displayed speed without disturbing totals.
   ///
   /// Used when samples stop arriving, so a stopped rider never sees a stale number.
   mutating func markSpeedStale() {
      speed = 0
      isMoving = false
      isOverridingStandstill = false
      grade = 0
      verticalSpeed = 0
      verticalWindow.removeAll()
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
         // A Wi-Fi fix is good enough to start the clock, not to measure from.
         seed(
            with: location,
            isCoarse: location.horizontalAccuracy > configuration.maxHorizontalAccuracy
         )
         return .acquiredFix
      }

      let isPrecise = location.horizontalAccuracy <= configuration.maxHorizontalAccuracy

      guard isPrecise || isUsableCoarseSample(location) else {
         rejectedSampleCount += 1
         return .rejected(.poorAccuracy)
      }

      // Re-anchoring needs a position worth anchoring to.
      if needsReseed {
         guard isPrecise else {
            rejectedSampleCount += 1
            return .rejected(.poorAccuracy)
         }
         needsReseed = false
         seed(with: location)
         return .reseeded
      }

      let interval = location.timestamp.timeIntervalSince(previous.timestamp)

      guard interval > 0.05 else {
         rejectedSampleCount += 1
         return .rejected(.staleTimestamp)
      }

      // A dropout must not become phantom distance or phantom moving time.
      guard interval <= configuration.maxSampleGap else {
         seed(with: location, isCoarse: !isPrecise)
         return .reseeded
      }

      let travelled = location.distance(from: previous)

      guard isPlausibleMove(travelled, over: interval, from: previous, to: location) else {
         rejectedSampleCount += 1
         return .rejected(.implausibleJump)
      }

      if isPrecise {
         coarseGeometry.reset()
         updateSpeed(with: location, travelled: travelled, interval: interval, isPrecise: true)
         updateTime(interval: interval)
         updateElevation(with: location)
         updateDistance(with: location)
      } else if hasReportedSpeed(location) {
         coarseGeometry.reset()
         updateSpeed(with: location, travelled: travelled, interval: interval, isPrecise: false)
         updateTime(interval: interval)
         integrateDistance(over: interval, at: location)
      } else {
         updateGeometricSpeed(with: location, interval: interval)
         updateTime(interval: interval)
      }

      updateGrade()
      updateCourse(with: location)

      lastAcceptedLocation = location
      acceptedSampleCount += 1
      return isPrecise ? .accepted : .acceptedCoarse
   }

   // MARK: - Seeding

   private mutating func seed(with location: CLLocation, isCoarse: Bool = false) {
      hasFix = true
      lastAcceptedLocation = location
      distanceAnchor = location
      anchorIsCoarse = isCoarse
      isOverridingStandstill = false

      // Never a geometry anchor, loose or not: the seed is where acquisition
      // happened to land, often a cached or Wi-Fi position far from the bike.
      // The first loose fix after it is the first point geometry measures from.
      coarseGeometry.reset()

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

   private mutating func updateSpeed(
      with location: CLLocation,
      travelled: Double,
      interval: TimeInterval,
      isPrecise: Bool
   ) {
      var reported = hasReportedSpeed(location)
         ? location.speed
         : travelled / interval

      // A reported standstill is checked against the ground actually covered
      // since the anchor last moved. Only a precise fix measured against a
      // precise anchor gets a say; coarse geometry is noise. Once geometry has
      // won it keeps carrying speed while the position keeps clearing the
      // noise floor, so the readout does not saw-tooth every time the anchor
      // advances.
      if isPrecise, reported < configuration.movingSpeedThreshold {
         if let geometric = standstillOverride(for: location) {
            reported = geometric
            isOverridingStandstill = true
         } else if isOverridingStandstill, travelled >= noiseFloor(for: location) {
            reported = travelled / interval
         } else {
            isOverridingStandstill = false
         }
      } else {
         isOverridingStandstill = false
      }

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

   /// Speed from displacement for a loose fix with no satellite speed.
   ///
   /// Nothing is published until the window has cleared twice (the first clear
   /// only sets the anchor), and never against the seed. Each pace is capped
   /// at twice the last published reading and at `maxGeometricSpeed`, then
   /// damped against the last — jitter can stretch one clear and squeeze the
   /// next, and a hero that reads 9, then 4, then 11 is the "random numbers"
   /// a rider reports. It is kept out of the ride maximum: the headline number
   /// must not be set by a Wi-Fi fix.
   private mutating func updateGeometricSpeed(with location: CLLocation, interval: TimeInterval) {
      isOverridingStandstill = false
      let wasMoving = isMoving

      switch coarseGeometry.ingest(location, configuration: configuration) {
         case .moving(let pace, let displacement, let elapsed):
            let ceiling = speed > 0
               ? min(speed * 2, configuration.maxGeometricSpeed)
               : configuration.maxGeometricSpeed
            speed = dampedGeometricSpeed(toward: min(pace, ceiling, configuration.maxPlausibleSpeed))
            coarseGeometry.holdPace(speed)
            isMoving = true
            distance += displacement
            appendGradePoint()

            // The ground just banked was covered while the first clear and
            // this one were being waited out, which `updateTime` billed as
            // stopped. Move that span across so distance / moving time is
            // the pace actually ridden, not a number inflated by the wait.
            if !wasMoving {
               let covered = min(stoppedTime, max(0, elapsed - interval))
               stoppedTime -= covered
               movingTime += covered
            }

         case .holding:
            break

         case .stopped:
            speed = 0
            isMoving = false
      }

      // The loose position becomes the anchor so a later precise fix
      // re-anchors there; whatever was banked above is never billed twice.
      distanceAnchor = location
      anchorIsCoarse = true
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
      guard let anchor = distanceAnchor, !anchorIsCoarse else {
         // No trustworthy anchor yet: this precise fix becomes it. Whatever
         // the bike covered between a loose anchor and here was already
         // integrated from speed, so adding the displacement would bill it twice.
         distanceAnchor = location
         anchorIsCoarse = false
         return
      }

      let travelled = location.distance(from: anchor)

      // The anchor only advances when real ground was covered, so slow riding
      // accumulates instead of being filtered away sample by sample.
      guard isMoving, travelled >= noiseFloor(for: location) else { return }

      distance += travelled
      distanceAnchor = location
      appendGradePoint()
   }

   /// Distance from satellite speed while the position is too loose to
   /// measure. The anchor follows the loose position so a later precise fix
   /// re-anchors there rather than against where the ride was before the
   /// signal softened.
   private mutating func integrateDistance(over interval: TimeInterval, at location: CLLocation) {
      distanceAnchor = location
      anchorIsCoarse = true

      guard isMoving else { return }

      distance += speed * interval
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

      updateVerticalSpeed(at: location.timestamp, altitude: smoothed)
   }

   // MARK: - Vertical Speed

   /// VAM from a time-stamped altitude window, alongside — never instead of —
   /// the distance-based grade math. Grade answers "how steep is this road";
   /// this answers "how many meters an hour am I actually gaining", which is
   /// the number climbers pace efforts by.
   private mutating func updateVerticalSpeed(at timestamp: Date, altitude: Double) {
      verticalWindow.append(VerticalPoint(timestamp: timestamp, altitude: altitude))

      let cutoff = timestamp.addingTimeInterval(-configuration.verticalSpeedWindow * 2)
      if let staleIndex = verticalWindow.lastIndex(where: { $0.timestamp < cutoff }), staleIndex > 0 {
         verticalWindow.removeFirst(staleIndex)
      }

      // The newest point at least a full window old anchors the measurement;
      // until one exists there is no honest figure, so the readout stays zero.
      guard let baseline = verticalWindow.last(where: {
         timestamp.timeIntervalSince($0.timestamp) >= configuration.verticalSpeedWindow
      }) else {
         verticalSpeed = 0
         return
      }

      let elapsed = timestamp.timeIntervalSince(baseline.timestamp)
      guard elapsed > 0 else { return }

      verticalSpeed = (altitude - baseline.altitude) / elapsed * 3_600
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
