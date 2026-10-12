//
//  RideTelemetryEngineTests.swift
//  BigVTests
//

import CoreLocation
import Testing
@testable import BigV

@MainActor
struct RideTelemetryEngineTests {

   // MARK: - Fixtures

   private static let origin = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
   private static let metersPerDegreeLatitude: Double = 111_320

   /// Builds a sample north of the origin by `northing` meters.
   private func sample(
      northing: Double,
      altitude: Double = 100,
      horizontalAccuracy: Double = 5,
      verticalAccuracy: Double = 5,
      speed: Double = 10,
      speedAccuracy: Double = 1,
      secondsFromStart: TimeInterval,
      reference: Date
   ) -> CLLocation {
      let latitude = Self.origin.latitude + (northing / Self.metersPerDegreeLatitude)

      return CLLocation(
         coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: Self.origin.longitude),
         altitude: altitude,
         horizontalAccuracy: horizontalAccuracy,
         verticalAccuracy: verticalAccuracy,
         course: 0,
         courseAccuracy: 5,
         speed: speed,
         speedAccuracy: speedAccuracy,
         timestamp: reference.addingTimeInterval(secondsFromStart)
      )
   }

   /// A Wi-Fi or cell fix: the hallmark 65 m circle and no satellite speed.
   private func wifiFix(
      northing: Double,
      secondsFromStart: TimeInterval,
      reference: Date
   ) -> CLLocation {
      sample(
         northing: northing,
         horizontalAccuracy: 65,
         verticalAccuracy: -1,
         speed: -1,
         speedAccuracy: -1,
         secondsFromStart: secondsFromStart,
         reference: reference
      )
   }

   /// Rides straight north at a steady speed.
   private func ride(
      into engine: inout RideTelemetryEngine,
      steps: Int,
      metersPerStep: Double = 10,
      speed: Double = 10,
      altitudePerStep: Double = 0,
      reference: Date = Date(timeIntervalSince1970: 1_000_000)
   ) {
      for step in 0...steps {
         let location = sample(
            northing: Double(step) * metersPerStep,
            altitude: 100 + Double(step) * altitudePerStep,
            speed: speed,
            secondsFromStart: Double(step),
            reference: reference
         )
         _ = engine.ingest(location)
      }
   }

   // MARK: - Fix Acquisition

   @Test func rejectsInvalidAccuracy() {
      var engine = RideTelemetryEngine()
      let reference = Date()

      let location = sample(
         northing: 0,
         horizontalAccuracy: -1,
         secondsFromStart: 0,
         reference: reference
      )

      #expect(engine.ingest(location) == .rejected(.invalidAccuracy))
      #expect(engine.hasFix == false)
   }

   @Test func rejectsPoorAccuracyBeforeFix() {
      var engine = RideTelemetryEngine()
      let reference = Date()

      let location = sample(
         northing: 0,
         horizontalAccuracy: 120,
         secondsFromStart: 0,
         reference: reference
      )

      #expect(engine.ingest(location) == .rejected(.poorAccuracy))
      #expect(engine.hasFix == false)
   }

   @Test func acquiresFixAtTheAcquisitionThreshold() {
      var engine = RideTelemetryEngine()
      let reference = Date()

      let location = sample(
         northing: 0,
         horizontalAccuracy: 65,
         secondsFromStart: 0,
         reference: reference
      )

      #expect(engine.ingest(location) == .acquiredFix)
      #expect(engine.hasFix)
   }

   @Test func acquiresFixOnUsableSample() {
      var engine = RideTelemetryEngine()
      let reference = Date()

      let location = sample(northing: 0, secondsFromStart: 0, reference: reference)

      #expect(engine.ingest(location) == .acquiredFix)
      #expect(engine.hasFix)
      #expect(engine.distance == 0)
   }

   // MARK: - Distance

   @Test func accumulatesDistanceOverASteadyRide() {
      var engine = RideTelemetryEngine()
      ride(into: &engine, steps: 10)

      // Ten accepted 10 m steps after the seeding sample.
      #expect(abs(engine.distance - 100) < 5)
      #expect(engine.isMoving)
      #expect(engine.movingTime == 10)
      #expect(engine.stoppedTime == 0)
   }

   @Test func doesNotAccumulateDistanceWhileStationary() {
      var engine = RideTelemetryEngine()
      ride(into: &engine, steps: 10, metersPerStep: 0, speed: 0)

      #expect(engine.distance == 0)
      #expect(engine.isMoving == false)
      #expect(engine.stoppedTime == 10)
      #expect(engine.movingTime == 0)
   }

   @Test func rejectsGPSJump() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)
      ride(into: &engine, steps: 5, reference: reference)

      let distanceBeforeJump = engine.distance
      let teleport = sample(northing: 5_000, speed: 10, secondsFromStart: 6, reference: reference)

      #expect(engine.ingest(teleport) == .rejected(.implausibleJump))
      #expect(engine.distance == distanceBeforeJump)
   }

   @Test func reseedsAfterSignalDropoutWithoutPhantomDistance() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)
      ride(into: &engine, steps: 5, reference: reference)

      let distanceBeforeDropout = engine.distance
      let movingTimeBeforeDropout = engine.movingTime

      // Reappears 2 km away a minute later, as if leaving a tunnel.
      let afterDropout = sample(northing: 2_000, speed: 10, secondsFromStart: 65, reference: reference)

      #expect(engine.ingest(afterDropout) == .reseeded)
      #expect(engine.distance == distanceBeforeDropout)
      #expect(engine.movingTime == movingTimeBeforeDropout)
   }

   // MARK: - Speed

   @Test func averageSpeedUsesMovingTime() {
      var engine = RideTelemetryEngine()
      ride(into: &engine, steps: 10)

      let expected = engine.distance / engine.movingTime
      #expect(abs(engine.averageSpeed - expected) < 0.001)
      #expect(engine.averageSpeed > 0)
   }

   @Test func maximumSpeedIgnoresASingleSpike() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)
      ride(into: &engine, steps: 10, reference: reference)

      let steadyMaximum = engine.maximumSpeed

      // One sample claiming 25 m/s while still only covering 10 m of ground.
      let spike = sample(northing: 110, speed: 25, secondsFromStart: 11, reference: reference)
      _ = engine.ingest(spike)

      // Smoothing keeps the spike from becoming the headline maximum.
      #expect(engine.maximumSpeed < 25)
      #expect(engine.maximumSpeed >= steadyMaximum)
   }

   @Test func markSpeedStaleZeroesSpeedButKeepsTotals() {
      var engine = RideTelemetryEngine()
      ride(into: &engine, steps: 10)

      let distance = engine.distance
      engine.markSpeedStale()

      #expect(engine.speed == 0)
      #expect(engine.isMoving == false)
      #expect(engine.distance == distance)
   }

   // MARK: - Elevation

   @Test func flatRideReportsNoElevationGain() {
      var engine = RideTelemetryEngine()
      ride(into: &engine, steps: 20, altitudePerStep: 0)

      #expect(engine.elevationGain == 0)
      #expect(engine.elevationLoss == 0)
   }

   @Test func climbAccumulatesElevationGain() {
      var engine = RideTelemetryEngine()
      ride(into: &engine, steps: 20, altitudePerStep: 3)

      #expect(engine.elevationGain > 20)
      #expect(engine.elevationLoss == 0)
   }

   @Test func ignoresAltitudeWithPoorVerticalAccuracy() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      for step in 0...20 {
         let location = sample(
            northing: Double(step) * 10,
            altitude: 100 + Double(step) * 3,
            verticalAccuracy: 90,
            speed: 10,
            secondsFromStart: Double(step),
            reference: reference
         )
         _ = engine.ingest(location)
      }

      #expect(engine.elevationGain == 0)
      #expect(engine.altitude == nil)
   }

   // MARK: - Grade

   @Test func gradeMatchesASustainedClimb() {
      var engine = RideTelemetryEngine()
      // 10 m forward per step, 0.6 m up per step, a 6 percent grade.
      ride(into: &engine, steps: 40, altitudePerStep: 0.6)

      #expect(engine.grade > 2)
      #expect(engine.grade < 8)
   }

   @Test func gradeIsZeroWhileStopped() {
      var engine = RideTelemetryEngine()
      ride(into: &engine, steps: 10, metersPerStep: 0, speed: 0)

      #expect(engine.grade == 0)
   }

   // MARK: - Vertical Speed

   @Test func vamMatchesASustainedClimb() {
      var engine = RideTelemetryEngine()
      // 0.5 m up per one-second step is 1 800 m/h, well past the 30 s window.
      ride(into: &engine, steps: 90, altitudePerStep: 0.5)

      #expect(engine.verticalSpeed > 1_400)
      #expect(engine.verticalSpeed < 2_200)
   }

   @Test func vamStaysZeroUntilTheWindowFills() {
      var engine = RideTelemetryEngine()
      // Fifteen seconds of climbing is not thirty; no honest figure exists yet.
      ride(into: &engine, steps: 15, altitudePerStep: 0.5)

      #expect(engine.verticalSpeed == 0)
   }

   @Test func vamGoesNegativeOnADescent() {
      var engine = RideTelemetryEngine()
      ride(into: &engine, steps: 90, altitudePerStep: -0.5)

      #expect(engine.verticalSpeed < -1_400)
   }

   @Test func staleSpeedZeroesVAM() {
      var engine = RideTelemetryEngine()
      ride(into: &engine, steps: 90, altitudePerStep: 0.5)

      engine.markSpeedStale()

      #expect(engine.verticalSpeed == 0)
   }

   // MARK: - Coarse Fixes

   /// The field report: START on a Wi-Fi fix, then a minute of GPS at 30–50 m
   /// while riding. Speed and distance must move during that minute.
   @Test func coarseGPSWithSatelliteSpeedDrivesSpeedAndDistance() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      #expect(engine.ingest(wifiFix(northing: 0, secondsFromStart: 0, reference: reference)) == .acquiredFix)

      // Sixty seconds at 4.5 m/s with the position still loose.
      for step in 1...60 {
         let fix = sample(
            northing: Double(step) * 4.5,
            horizontalAccuracy: 40,
            verticalAccuracy: 30,
            speed: 4.5,
            secondsFromStart: Double(step),
            reference: reference
         )
         #expect(engine.ingest(fix) == .acceptedCoarse)
      }

      #expect(engine.isMoving)
      #expect(abs(engine.speed - 4.5) < 0.01)
      #expect(abs(engine.distance - 270) < 10)
      #expect(engine.movingTime == 60)
      #expect(engine.altitude == nil)
   }

   @Test func aSingleWifiFixAfterAcquisitionReadsZero() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      _ = engine.ingest(wifiFix(northing: 0, secondsFromStart: 0, reference: reference))

      // Accepted — it may become evidence later — but 30 m between two 65 m
      // circles is nothing yet.
      let outcome = engine.ingest(wifiFix(northing: 30, secondsFromStart: 1, reference: reference))

      #expect(outcome == .acceptedCoarse)
      #expect(engine.distance == 0)
      #expect(engine.speed == 0)
      #expect(engine.isMoving == false)
   }

   @Test func coarseJitterIsNotAnImplausibleJump() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      _ = engine.ingest(wifiFix(northing: 0, secondsFromStart: 0, reference: reference))
      _ = engine.ingest(
         sample(northing: 0, horizontalAccuracy: 50, speed: 4, secondsFromStart: 1, reference: reference)
      )

      // 60 m between two 50 m fixes a second apart is jitter, not 60 m/s.
      let jittery = sample(northing: 60, horizontalAccuracy: 50, speed: 4, secondsFromStart: 2, reference: reference)
      #expect(engine.ingest(jittery) == .acceptedCoarse)
   }

   @Test func coarseStandstillAddsNoDistance() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      _ = engine.ingest(wifiFix(northing: 0, secondsFromStart: 0, reference: reference))

      // Parked at the kerb with the position wandering 20 m either way.
      for step in 1...30 {
         let wander = step.isMultiple(of: 2) ? 20.0 : -20.0
         _ = engine.ingest(
            sample(northing: wander, horizontalAccuracy: 45, speed: 0, secondsFromStart: Double(step), reference: reference)
         )
      }

      #expect(engine.distance == 0)
      #expect(engine.isMoving == false)
      #expect(engine.stoppedTime == 30)
   }

   @Test func firstPreciseFixAfterCoarseOnesReanchorsWithoutDoubleBilling() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      _ = engine.ingest(wifiFix(northing: 0, secondsFromStart: 0, reference: reference))

      for step in 1...20 {
         _ = engine.ingest(
            sample(northing: Double(step) * 5, horizontalAccuracy: 40, speed: 5, secondsFromStart: Double(step), reference: reference)
         )
      }
      let integrated = engine.distance
      #expect(abs(integrated - 100) < 10)

      // The lock tightens. The 100 m already integrated must not be added again
      // as displacement from the loose anchor.
      let precise = sample(northing: 105, horizontalAccuracy: 6, speed: 5, secondsFromStart: 21, reference: reference)
      #expect(engine.ingest(precise) == .accepted)
      #expect(engine.distance == integrated)

      // And precise riding accumulates from the new anchor as before.
      for step in 22...30 {
         _ = engine.ingest(
            sample(northing: Double(step) * 5, horizontalAccuracy: 6, speed: 5, secondsFromStart: Double(step), reference: reference)
         )
      }
      #expect(engine.distance > integrated + 30)
      #expect(engine.distance < integrated + 60)
   }

   @Test func reseedWaitsForAPreciseFix() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)
      ride(into: &engine, steps: 5, reference: reference)

      engine.invalidateAnchor()

      let loose = sample(northing: 200, horizontalAccuracy: 40, speed: 5, secondsFromStart: 30, reference: reference)
      #expect(engine.ingest(loose) == .rejected(.poorAccuracy))

      let tight = sample(northing: 205, horizontalAccuracy: 5, speed: 5, secondsFromStart: 31, reference: reference)
      #expect(engine.ingest(tight) == .reseeded)
   }

   // MARK: - Coarse Geometry

   /// A 40 m fix with no satellite speed: Wi-Fi positioning on a residential
   /// street, which is what the rider's video shows for 104 seconds.
   private func wifiFix40(
      northing: Double,
      secondsFromStart: TimeInterval,
      reference: Date
   ) -> CLLocation {
      sample(
         northing: northing,
         horizontalAccuracy: 40,
         verticalAccuracy: -1,
         speed: -1,
         speedAccuracy: -1,
         secondsFromStart: secondsFromStart,
         reference: reference
      )
   }

   /// The video: START on a Wi-Fi fix, then only 40 m speed-less fixes while
   /// riding at 15 mph. Speed must read and distance must bank from position
   /// alone, well inside the 104 s the rider waited.
   @Test func fortyMetreFixesWithoutSatelliteSpeedStillDriveSpeedAndDistance() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)
      let metersPerSecond = 6.7

      #expect(engine.ingest(wifiFix(northing: 0, secondsFromStart: 0, reference: reference)) == .acquiredFix)

      var firstLiveSpeedAt: TimeInterval?

      for step in 1...60 {
         let outcome = engine.ingest(
            wifiFix40(northing: Double(step) * metersPerSecond, secondsFromStart: Double(step), reference: reference)
         )
         #expect(outcome == .acceptedCoarse)

         if firstLiveSpeedAt == nil, engine.speed > 0 {
            firstLiveSpeedAt = Double(step)
         }
      }

      // The seed is never measured from: the first 40 m fix anchors, the
      // next clear (80 m, 12 s at 6.7 m/s) only moves the anchor, and the
      // clear after it publishes.
      #expect(firstLiveSpeedAt != nil)
      #expect((firstLiveSpeedAt ?? .infinity) <= 30)
      #expect((firstLiveSpeedAt ?? 0) >= 24)

      #expect(engine.isMoving)
      #expect(abs(engine.speed - metersPerSecond) < 0.5)

      // Only ground that cleared the bar is banked; the tail since the last
      // clear (under 80 m) waits for the next one rather than being guessed.
      #expect(engine.distance > 200)
      #expect(engine.distance <= 60 * metersPerSecond + 1)
      #expect(engine.movingTime >= 40)

      // Time waited out before the confirming clear counts as moving, so
      // distance over moving time reads the ridden pace, not an inflated one.
      #expect(engine.averageSpeed <= metersPerSecond * 1.1)
   }

   @Test func fortyMetreFixesJitteringAtAStandstillReadZero() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      _ = engine.ingest(wifiFix40(northing: 0, secondsFromStart: 0, reference: reference))

      // Parked. The Wi-Fi position wanders 10–20 m either way, every second.
      let jitter: [Double] = [10, -15, 20, -10, 15, -20]
      for step in 1...90 {
         _ = engine.ingest(
            wifiFix40(northing: jitter[step % jitter.count], secondsFromStart: Double(step), reference: reference)
         )
      }

      #expect(engine.speed == 0)
      #expect(engine.isMoving == false)
      #expect(engine.distance == 0)
      #expect(engine.stoppedTime == 90)
   }

   @Test func walkingPaceDriftUnderFortyMetreFixesReadsZero() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      _ = engine.ingest(wifiFix40(northing: 0, secondsFromStart: 0, reference: reference))

      // 0.5 m/s is 60 m over two minutes — further than the bar, but the
      // anchor slides every 30 s, so it is never more than 15 m behind.
      for step in 1...120 {
         _ = engine.ingest(
            wifiFix40(northing: Double(step) * 0.5, secondsFromStart: Double(step), reference: reference)
         )
      }

      #expect(engine.speed == 0)
      #expect(engine.isMoving == false)
      #expect(engine.distance == 0)
   }

   @Test func geometricSpeedReturnsToZeroAfterAStop() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      _ = engine.ingest(wifiFix40(northing: 0, secondsFromStart: 0, reference: reference))

      for step in 1...30 {
         _ = engine.ingest(
            wifiFix40(northing: Double(step) * 6.7, secondsFromStart: Double(step), reference: reference)
         )
      }
      #expect(engine.speed > 6)
      let bankedWhileRolling = engine.distance

      // Stopped dead at the light; the position holds.
      for step in 31...70 {
         _ = engine.ingest(
            wifiFix40(northing: 30 * 6.7, secondsFromStart: Double(step), reference: reference)
         )
      }

      #expect(engine.speed == 0)
      #expect(engine.isMoving == false)
      #expect(engine.distance == bankedWhileRolling)
   }

   @Test func precisionReturningAfterGeometricFixesDoesNotDoubleBill() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      _ = engine.ingest(wifiFix40(northing: 0, secondsFromStart: 0, reference: reference))

      for step in 1...40 {
         _ = engine.ingest(
            wifiFix40(northing: Double(step) * 6.7, secondsFromStart: Double(step), reference: reference)
         )
      }
      let banked = engine.distance
      #expect(banked > 150)

      // GPS locks. The metres already banked from displacement must not come
      // back as one straight line from the loose anchor.
      let locked = sample(northing: 41 * 6.7, horizontalAccuracy: 6, speed: 6.7, secondsFromStart: 41, reference: reference)
      #expect(engine.ingest(locked) == .accepted)
      #expect(engine.distance == banked)

      for step in 42...60 {
         _ = engine.ingest(
            sample(northing: Double(step) * 6.7, horizontalAccuracy: 6, speed: 6.7, secondsFromStart: Double(step), reference: reference)
         )
      }

      // Nineteen precise 6.7 m steps on top, and nothing else.
      #expect(engine.distance > banked + 19 * 6.7 - 10)
      #expect(engine.distance < banked + 19 * 6.7 + 10)
   }

   /// Jitter stretches one clear and squeezes the next: raw paces of 9, 4,
   /// 11 m/s while riding 6.7. The hero must walk between them, never jump
   /// by more than half, and never read zero while the position advances.
   @Test func geometricSpeedNeverJumpsByMoreThanHalfBetweenPaces() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)
      let metersPerSecond = 6.7

      _ = engine.ingest(wifiFix40(northing: 0, secondsFromStart: 0, reference: reference))

      var previousSpeed = 0.0
      var largestRatio = 1.0
      var zeroWhileRolling = false
      var rollingSpeeds: [Double] = []

      // Up to ±25 m of along-track wobble on top of true progress, held for
      // a few seconds at a time the way a Wi-Fi position lurches, with a
      // period that does not line up with the clear interval.
      let wobbles: [Double] = [12, -20, 5, 25, -8, -25, 18, -3, 22, -15, 0]

      for step in 1...180 {
         let wobble = wobbles[(step / 5) % wobbles.count]
         _ = engine.ingest(
            wifiFix40(
               northing: Double(step) * metersPerSecond + wobble,
               secondsFromStart: Double(step),
               reference: reference
            )
         )

         if previousSpeed > 0, engine.speed > 0 {
            let ratio = max(engine.speed, previousSpeed) / min(engine.speed, previousSpeed)
            largestRatio = max(largestRatio, ratio)
         }
         if step > 40 {
            if engine.speed == 0 { zeroWhileRolling = true }
            rollingSpeeds.append(engine.speed)
         }
         previousSpeed = engine.speed
      }

      #expect(largestRatio <= 1.5 + 0.001)
      #expect(!zeroWhileRolling)
      #expect(engine.isMoving)

      // Individual paces are stretched and squeezed by design; the readout
      // as a whole must still centre on the true speed.
      let mean = rollingSpeeds.reduce(0, +) / Double(rollingSpeeds.count)
      #expect(abs(mean - metersPerSecond) < 1.5)
   }

   @Test func dampedGeometricSpeedTakesTheFirstPaceWholeAndCapsLaterSteps() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      // No speed yet: the first pace is the reading.
      #expect(engine.dampedGeometricSpeed(toward: 6.7) == 6.7)

      // Establish a steady 6.7 m/s from geometry.
      _ = engine.ingest(wifiFix40(northing: 0, secondsFromStart: 0, reference: reference))
      for step in 1...40 {
         _ = engine.ingest(
            wifiFix40(northing: Double(step) * 6.7, secondsFromStart: Double(step), reference: reference)
         )
      }
      let steady = engine.speed
      #expect(steady > 6)

      // A pace three times higher moves the reading by at most half.
      #expect(engine.dampedGeometricSpeed(toward: steady * 3) <= steady * 1.5 + 0.001)

      // A pace a tenth of it drops the reading by at most half.
      #expect(engine.dampedGeometricSpeed(toward: steady * 0.1) >= steady * 0.5 - 0.001)

      // A nearby pace is blended, not snapped.
      let nudged = engine.dampedGeometricSpeed(toward: steady + 1)
      #expect(nudged > steady && nudged < steady + 1)
   }

   // MARK: - Geometric Speed Guards

   /// Field report: 31.9 mph at a standstill right after START. The seed was
   /// a cached position 100 m from the bike, and the first loose fix "rode"
   /// there in a second or two.
   @Test func aFixFarFromTheSeedNeverPublishesGeometricSpeed() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      _ = engine.ingest(wifiFix(northing: 0, secondsFromStart: 0, reference: reference))
      _ = engine.ingest(wifiFix40(northing: 100, secondsFromStart: 10, reference: reference))

      #expect(engine.speed == 0)
      #expect(engine.isMoving == false)
      #expect(engine.distance == 0)
   }

   @Test func aSingleHundredMetreJumpMidRideReadsZero() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      _ = engine.ingest(wifiFix40(northing: 0, secondsFromStart: 0, reference: reference))
      for step in 1...5 {
         _ = engine.ingest(wifiFix40(northing: 0, secondsFromStart: Double(step), reference: reference))
      }

      // One lurch, then the position settles there. One clear only anchors.
      for step in 6...12 {
         _ = engine.ingest(wifiFix40(northing: 100, secondsFromStart: Double(step), reference: reference))
         #expect(engine.speed == 0)
      }

      #expect(engine.isMoving == false)
      #expect(engine.distance == 0)
      #expect(engine.maximumSpeed == 0)
   }

   @Test func twoConsistentClearsPublishABoundedGeometricSpeed() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)
      let metersPerSecond = 6.7

      _ = engine.ingest(wifiFix40(northing: 0, secondsFromStart: 0, reference: reference))

      var published = false
      for step in 1...45 {
         _ = engine.ingest(
            wifiFix40(northing: Double(step) * metersPerSecond, secondsFromStart: Double(step), reference: reference)
         )
         #expect(engine.speed <= 12)
         if engine.speed > 0 { published = true }
      }

      #expect(published)
      #expect(engine.speed > 0)
      #expect(engine.maximumSpeed == 0)
   }

   @Test func satelliteSpeedIsPreferredOverGeometryWhenPresent() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      _ = engine.ingest(wifiFix40(northing: 0, secondsFromStart: 0, reference: reference))

      // Same loose accuracy, but Core Location measured the speed: the
      // readout must not wait 12 s for displacement to clear a bar.
      let doppler = sample(northing: 6.7, horizontalAccuracy: 40, speed: 6.7, secondsFromStart: 1, reference: reference)
      #expect(engine.ingest(doppler) == .acceptedCoarse)
      #expect(abs(engine.speed - 6.7) < 0.01)
      #expect(engine.isMoving)
   }

   // MARK: - Standstill Override

   /// Core Location reporting 0 m/s while the position advances 4.5 m every
   /// second. Geometry has to win once the displacement is past jitter.
   @Test func reportedZeroSpeedYieldsToClearDisplacement() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      _ = engine.ingest(sample(northing: 0, speed: 0, secondsFromStart: 0, reference: reference))

      for step in 1...20 {
         _ = engine.ingest(
            sample(northing: Double(step) * 4.5, speed: 0, secondsFromStart: Double(step), reference: reference)
         )
      }

      #expect(engine.isMoving)
      #expect(engine.speed > 1)
      #expect(engine.distance > 60)
      #expect(engine.movingTime > 10)
   }

   @Test func reportedZeroSpeedIsTrustedWhenThePositionOnlyJitters() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      _ = engine.ingest(sample(northing: 0, speed: 0, secondsFromStart: 0, reference: reference))

      // Standing still with the fix wobbling inside its 5 m circle.
      for step in 1...30 {
         let wobble = step.isMultiple(of: 2) ? 3.0 : -3.0
         _ = engine.ingest(
            sample(northing: wobble, speed: 0, secondsFromStart: Double(step), reference: reference)
         )
      }

      #expect(engine.isMoving == false)
      #expect(engine.speed == 0)
      #expect(engine.distance == 0)
   }

   @Test func slowDriftOverMinutesIsNotMovement() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      _ = engine.ingest(sample(northing: 0, speed: 0, secondsFromStart: 0, reference: reference))

      // 15 m of drift spread over two minutes is 0.125 m/s: parked.
      for step in 1...120 {
         _ = engine.ingest(
            sample(northing: Double(step) * 0.125, speed: 0, secondsFromStart: Double(step), reference: reference)
         )
      }

      #expect(engine.isMoving == false)
      #expect(engine.distance == 0)
   }

   // MARK: - Reset

   @Test func resetClearsEverything() {
      var engine = RideTelemetryEngine()
      ride(into: &engine, steps: 10, altitudePerStep: 2)

      engine.reset()

      #expect(engine.distance == 0)
      #expect(engine.speed == 0)
      #expect(engine.maximumSpeed == 0)
      #expect(engine.movingTime == 0)
      #expect(engine.elevationGain == 0)
      #expect(engine.hasFix == false)
      #expect(engine.altitude == nil)
      #expect(engine.verticalSpeed == 0)
   }

   // MARK: - Restore

   @Test func restoringCarriesTheInterruptedRideTotalsForward() {
      var engine = RideTelemetryEngine()

      engine.restore(
         RideTelemetryEngine.RestoredTotals(
            distance: 22_500,
            movingTime: 3_300,
            maximumSpeed: 14.2,
            elevationGain: 380,
            elevationLoss: 260,
            altitude: 190,
            acceptedSampleCount: 3_310
         )
      )

      #expect(engine.distance == 22_500)
      #expect(engine.movingTime == 3_300)
      #expect(engine.maximumSpeed == 14.2)
      #expect(engine.elevationGain == 380)
      #expect(engine.elevationLoss == 260)
      #expect(engine.altitude == 190)
      #expect(engine.acceptedSampleCount == 3_310)

      // No fix and no anchor: the next sample has to re-seed rather than be
      // measured against wherever the rider was an hour ago.
      #expect(!engine.hasFix)
      #expect(engine.speed == 0)
   }

   @Test func theFirstSampleAfterARestoreAddsNoPhantomDistance() {
      var engine = RideTelemetryEngine()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      engine.restore(
         RideTelemetryEngine.RestoredTotals(distance: 22_500, acceptedSampleCount: 3_310)
      )

      // Miles from where the ride was recording when the app was killed.
      let elsewhere = sample(northing: 30_000, secondsFromStart: 0, reference: reference)
      #expect(engine.ingest(elsewhere) == .acquiredFix)
      #expect(engine.distance == 22_500)

      // And ordinary riding accumulates on top from there.
      for step in 1...20 {
         _ = engine.ingest(
            sample(
               northing: 30_000 + Double(step) * 10,
               secondsFromStart: Double(step),
               reference: reference
            )
         )
      }

      #expect(engine.distance > 22_500)
      #expect(engine.distance < 22_500 + 400)
   }

   @Test func restoringReplacesAnyEarlierTotals() {
      var engine = RideTelemetryEngine()
      ride(into: &engine, steps: 30)
      #expect(engine.distance > 0)

      engine.restore(RideTelemetryEngine.RestoredTotals())

      #expect(engine.distance == 0)
      #expect(engine.movingTime == 0)
      #expect(engine.altitude == nil)
   }
}
