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
         speedAccuracy: 1,
         timestamp: reference.addingTimeInterval(secondsFromStart)
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
