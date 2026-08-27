//
//  RouteGuidanceEngineTests.swift
//  BigVTests
//

import CoreLocation
import Testing
@testable import BigV

@MainActor
struct RouteGuidanceEngineTests {

   // MARK: - Fixtures

   private static let origin = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
   private static let reference = Date(timeIntervalSince1970: 1_000_000)

   private func point(east: Double, north: Double = 0) -> CLLocationCoordinate2D {
      RouteGuidanceTestGeography.coordinate(east: east, north: north, from: Self.origin)
   }

   /// A line running east, one vertex every 20 meters.
   private func straightLine(length: Double, north: Double = 0) -> [CLLocationCoordinate2D] {
      stride(from: 0, through: length, by: 20).map { point(east: $0, north: north) }
   }

   /// Out east and back again, five meters to the north — the pathological shape
   /// that makes nearest-point projection unsafe.
   private func hairpin(length: Double) -> [CLLocationCoordinate2D] {
      straightLine(length: length) + Array(straightLine(length: length, north: 5).reversed())
   }

   private func maneuver(
      _ id: Int,
      _ instruction: String,
      at distanceFromStart: CLLocationDistance,
      notice: String? = nil
   ) -> PlannedRouteManeuver {
      PlannedRouteManeuver(
         id: id,
         instruction: instruction,
         notice: notice,
         distance: 0,
         distanceFromStart: distanceFromStart,
         coordinate: point(east: distanceFromStart)
      )
   }

   /// `distance` of nil leaves the engine to measure the geometry, which is what
   /// happens when a provider gives no total.
   private func route(
      _ coordinates: [CLLocationCoordinate2D],
      maneuvers: [PlannedRouteManeuver] = [],
      distance: CLLocationDistance? = nil
   ) -> PlannedRoute {
      PlannedRoute(
         id: UUID(),
         source: .appleMaps,
         name: "Test Route",
         coordinates: coordinates,
         distance: distance ?? 0,
         expectedTravelTime: 0,
         maneuvers: maneuvers,
         advisories: []
      )
   }

   private func fix(
      east: Double,
      north: Double = 0,
      course: Double = 90,
      speed: Double = 6,
      second: TimeInterval
   ) -> RouteGuidanceFix {
      RouteGuidanceFix(
         coordinate: point(east: east, north: north),
         course: course,
         speed: speed,
         timestamp: Self.reference.addingTimeInterval(second)
      )
   }

   /// Rides east along a route in even steps, returning every event produced.
   @discardableResult
   private func ride(
      into engine: inout RouteGuidanceEngine,
      from start: Double,
      to end: Double,
      step: Double = 20,
      north: Double = 0,
      course: Double = 90,
      speed: Double = 6,
      startingAtSecond: TimeInterval = 0
   ) -> [RouteGuidanceEvent] {
      var events: [RouteGuidanceEvent] = []
      var east = start
      var second = startingAtSecond

      while step > 0 ? east <= end + 0.001 : east >= end - 0.001 {
         events += engine.ingest(
            fix(east: east, north: north, course: course, speed: speed, second: second)
         )
         east += step
         second += abs(step) / max(1, speed)
      }

      return events
   }

   private func cues(in events: [RouteGuidanceEvent]) -> [RouteGuidanceCue] {
      events.compactMap {
         guard case .cue(let cue) = $0 else { return nil }
         return cue
      }
   }

   private func count(of event: RouteGuidanceEvent, in events: [RouteGuidanceEvent]) -> Int {
      events.filter { $0 == event }.count
   }

   // MARK: - Degenerate Routes

   @Test func anEmptyRouteIsNotGuidable() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route([]))

      #expect(engine.isReady == false)
      #expect(engine.ingest(fix(east: 0, second: 0)).isEmpty)
      #expect(engine.progress == .inactive)
   }

   @Test func aSingleCoordinateRouteIsNotGuidable() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route([point(east: 0)]))

      #expect(engine.isReady == false)
      #expect(engine.ingest(fix(east: 0, second: 0)).isEmpty)
   }

   @Test func aRouteOfIdenticalPointsIsNotGuidable() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(Array(repeating: point(east: 0), count: 20)))

      #expect(engine.isReady == false)
      #expect(engine.ingest(fix(east: 0, second: 0)).isEmpty)
   }

   @Test func anUnpreparedEngineIgnoresSamples() {
      var engine = RouteGuidanceEngine()

      #expect(engine.isReady == false)
      #expect(engine.ingest(fix(east: 0, second: 0)).isEmpty)
      #expect(engine.progress.isTracking == false)
   }

   @Test func anUnusableCoordinateIsIgnored() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(straightLine(length: 200)))
      ride(into: &engine, from: 0, to: 100)

      let before = engine.progress
      let nullIsland = RouteGuidanceFix(
         coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
         speed: 6,
         timestamp: Self.reference.addingTimeInterval(500)
      )

      #expect(engine.ingest(nullIsland).isEmpty)
      #expect(engine.progress == before)
   }

   // MARK: - Progress

   @Test func aStraightRouteTracksProgressAlongIt() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(straightLine(length: 1_000)))

      ride(into: &engine, from: 0, to: 400)

      #expect(engine.progress.isTracking)
      #expect(abs(engine.progress.distanceAlongRoute - 400) < 10)
      #expect(abs(engine.progress.distanceRemaining - 600) < 12)
      #expect(engine.progress.lateralDeviation < 3)
   }

   @Test func aRiderStartingFromTheMiddleIsPlacedThere() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(straightLine(length: 1_000)))

      _ = engine.ingest(fix(east: 500, second: 0))

      #expect(abs(engine.progress.distanceAlongRoute - 500) < 10)
      #expect(engine.progress.isOffRoute == false)
   }

   /// The doubling-back case at engine level: a rider fifty meters into a hairpin
   /// must not be placed on the return leg seven hundred meters ahead.
   @Test func aRouteThatDoublesBackDoesNotSnapAhead() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(hairpin(length: 400)))

      _ = engine.ingest(fix(east: 50, north: 1, course: 90, second: 0))

      #expect(abs(engine.progress.distanceAlongRoute - 50) < 20)
   }

   @Test func aRiderOnTheReturnLegOfAHairpinIsPlacedThere() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(hairpin(length: 400)))

      _ = engine.ingest(fix(east: 50, north: 4, course: 270, second: 0))

      #expect(engine.progress.distanceAlongRoute > 600)
   }

   @Test func progressNeverGoesBackwardsWhileRidingAHairpinForwards() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(hairpin(length: 400)))

      var samples: [Double] = []
      var second: TimeInterval = 0

      for east in stride(from: 0.0, through: 400, by: 20) {
         _ = engine.ingest(fix(east: east, course: 90, second: second))
         samples.append(engine.progress.distanceAlongRoute)
         second += 4
      }

      for east in stride(from: 400.0, through: 0, by: -20) {
         _ = engine.ingest(fix(east: east, north: 5, course: 270, second: second))
         samples.append(engine.progress.distanceAlongRoute)
         second += 4
      }

      let regressions = zip(samples, samples.dropFirst()).filter { $1 < $0 - 5 }
      #expect(regressions.isEmpty)
      #expect((samples.last ?? 0) > 700)
   }

   @Test func aRiderRetracingTheRouteIsCalledOut() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(straightLine(length: 1_000)))

      ride(into: &engine, from: 0, to: 300)
      #expect(engine.progress.isAgainstRoute == false)

      ride(into: &engine, from: 280, to: 200, step: -20, course: 270, startingAtSecond: 100)

      #expect(engine.progress.isAgainstRoute)
   }

   @Test func ridingForwardsAgainClearsTheWrongWayFlag() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(straightLine(length: 1_000)))

      ride(into: &engine, from: 0, to: 300)
      ride(into: &engine, from: 280, to: 200, step: -20, course: 270, startingAtSecond: 100)
      #expect(engine.progress.isAgainstRoute)

      ride(into: &engine, from: 220, to: 320, course: 90, startingAtSecond: 200)

      #expect(engine.progress.isAgainstRoute == false)
   }

   // MARK: - Maneuvers

   @Test func theUpcomingManeuverAdvancesAsTurnsArePassed() {
      var engine = RouteGuidanceEngine()
      engine.prepare(
         route(
            straightLine(length: 1_000),
            maneuvers: [
               maneuver(0, "Turn left", at: 200),
               maneuver(1, "Turn right", at: 600),
               maneuver(2, "Arrive", at: 1_000)
            ]
         )
      )

      ride(into: &engine, from: 0, to: 100)
      #expect(engine.progress.upcomingManeuverID == 0)
      #expect(engine.progress.upcomingInstruction == "Turn left")

      ride(into: &engine, from: 120, to: 400, startingAtSecond: 100)
      #expect(engine.progress.upcomingManeuverID == 1)

      ride(into: &engine, from: 420, to: 800, startingAtSecond: 300)
      #expect(engine.progress.upcomingManeuverID == 2)
   }

   @Test func distanceToTheNextManeuverIsTheOffsetLessProgress() {
      var engine = RouteGuidanceEngine()
      engine.prepare(
         route(straightLine(length: 1_000), maneuvers: [maneuver(0, "Turn left", at: 600)])
      )

      ride(into: &engine, from: 0, to: 400)

      let distance = engine.progress.distanceToUpcomingManeuver ?? 0
      #expect(abs(distance - 200) < 12)
   }

   @Test func theInstructionAfterTheNextOneIsOffered() {
      var engine = RouteGuidanceEngine()
      engine.prepare(
         route(
            straightLine(length: 1_000),
            maneuvers: [
               maneuver(0, "Turn left", at: 300),
               maneuver(1, "Turn right", at: 500)
            ]
         )
      )

      ride(into: &engine, from: 0, to: 100)

      #expect(engine.progress.upcomingInstruction == "Turn left")
      #expect(engine.progress.followingInstruction == "Turn right")

      ride(into: &engine, from: 120, to: 400, startingAtSecond: 100)

      #expect(engine.progress.upcomingInstruction == "Turn right")
      #expect(engine.progress.followingInstruction == nil)
   }

   @Test func aNoticeOnTheUpcomingStepIsCarried() {
      var engine = RouteGuidanceEngine()
      engine.prepare(
         route(
            straightLine(length: 400),
            maneuvers: [maneuver(0, "Cross the tracks", at: 200, notice: "Level crossing")]
         )
      )

      ride(into: &engine, from: 0, to: 100)

      #expect(engine.progress.upcomingNotice == "Level crossing")
   }

   @Test func aRouteWithNoManeuversStillReportsWhatIsLeft() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(straightLine(length: 800)))

      ride(into: &engine, from: 0, to: 300)

      #expect(engine.progress.upcomingInstruction == nil)
      #expect(engine.progress.distanceToUpcomingManeuver == nil)
      #expect(abs(engine.progress.distanceRemaining - 500) < 12)
   }

   /// Maneuver offsets live in the provider's distance space, not the drawn
   /// polyline's. Without scaling, distance-to-turn drifts by the difference.
   @Test func maneuverOffsetsAreScaledIntoTheProvidersDistanceSpace() {
      var engine = RouteGuidanceEngine()
      engine.prepare(
         route(
            straightLine(length: 1_000),
            maneuvers: [maneuver(0, "Arrive", at: 1_100)],
            distance: 1_100
         )
      )

      ride(into: &engine, from: 0, to: 500)

      // Geometry progress of 500 m is 550 m in the provider's space, so 550 m
      // remains to a turn at 1,100 — not the 600 an unscaled subtraction gives.
      let distance = engine.progress.distanceToUpcomingManeuver ?? 0
      #expect(abs(distance - 550) < 15)
      #expect(abs(engine.progress.distanceRemaining - 550) < 15)
   }

   // MARK: - Off Route Hysteresis

   @Test func aBriefGPSExcursionDoesNotTriggerOffRoute() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(straightLine(length: 1_000)))
      ride(into: &engine, from: 0, to: 200)

      var events: [RouteGuidanceEvent] = []

      // Three samples ninety meters off the line, as multipath under a bridge
      // produces, then straight back.
      for (index, east) in [220.0, 240, 260].enumerated() {
         events += engine.ingest(
            fix(east: east, north: 90, second: 100 + Double(index))
         )
      }

      events += engine.ingest(fix(east: 280, second: 104))

      #expect(count(of: .departedRoute, in: events) == 0)
      #expect(engine.progress.isOffRoute == false)
   }

   @Test func aSustainedDeviationTriggersOffRouteExactlyOnce() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(straightLine(length: 2_000)))
      ride(into: &engine, from: 0, to: 200)

      var events: [RouteGuidanceEvent] = []

      // Twelve samples across twenty-two seconds, ninety meters off the line: past
      // both the sample count and the twelve-second window.
      for index in 0..<12 {
         events += engine.ingest(
            fix(east: 220 + Double(index) * 6, north: 90, second: 100 + Double(index) * 2)
         )
      }

      #expect(count(of: .departedRoute, in: events) == 1)
      #expect(engine.progress.isOffRoute)
   }

   /// The sample count alone must not confirm: a burst of fast fixes is not a
   /// rider who has had time to leave the route.
   @Test func offRouteNeedsTheDurationAsWellAsTheSampleCount() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(straightLine(length: 1_000)))
      ride(into: &engine, from: 0, to: 200)

      var events: [RouteGuidanceEvent] = []

      for index in 0..<10 {
         events += engine.ingest(
            fix(east: 220, north: 90, second: 100 + Double(index) * 0.4)
         )
      }

      #expect(count(of: .departedRoute, in: events) == 0)
      #expect(engine.progress.isOffRoute == false)
   }

   /// A sample in the gap between the two thresholds holds the streak rather than
   /// resetting it, which is what makes the trigger a Schmitt trigger rather than
   /// something that flaps.
   @Test func aSampleInTheHysteresisGapNeitherConfirmsNorClears() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(straightLine(length: 2_000)))
      ride(into: &engine, from: 0, to: 200)

      var events: [RouteGuidanceEvent] = []
      var second: TimeInterval = 100

      for north in [60.0, 60, 32, 32, 60, 60, 60] {
         events += engine.ingest(fix(east: 220, north: north, second: second))
         second += 3
      }

      #expect(count(of: .departedRoute, in: events) == 1)
   }

   @Test func returningInsideTheOnRouteThresholdResetsTheStreak() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(straightLine(length: 2_000)))
      ride(into: &engine, from: 0, to: 200)

      var events: [RouteGuidanceEvent] = []
      var second: TimeInterval = 100

      for north in [60.0, 60, 60, 60, 5, 60, 60, 60] {
         events += engine.ingest(fix(east: 220, north: north, second: second))
         second += 3
      }

      #expect(count(of: .departedRoute, in: events) == 0)
   }

   @Test func offRouteClearsOnlyAfterSustainedReacquisition() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(straightLine(length: 2_000)))
      ride(into: &engine, from: 0, to: 200)

      var events: [RouteGuidanceEvent] = []

      for index in 0..<12 {
         events += engine.ingest(fix(east: 220, north: 90, second: 100 + Double(index) * 2))
      }
      #expect(engine.progress.isOffRoute)

      // One good sample is not enough.
      events += engine.ingest(fix(east: 300, second: 130))
      #expect(engine.progress.isOffRoute)

      events += engine.ingest(fix(east: 320, second: 134))
      events += engine.ingest(fix(east: 340, second: 138))

      #expect(engine.progress.isOffRoute == false)
      #expect(count(of: .regainedRoute, in: events) == 1)
      #expect(abs(engine.progress.distanceAlongRoute - 340) < 15)
   }

   @Test func progressIsFrozenWhileOffRoute() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(straightLine(length: 2_000)))
      ride(into: &engine, from: 0, to: 200)

      for index in 0..<12 {
         _ = engine.ingest(fix(east: 220, north: 90, second: 100 + Double(index) * 2))
      }

      let frozen = engine.progress.distanceAlongRoute

      for index in 0..<6 {
         _ = engine.ingest(fix(east: 400 + Double(index) * 40, north: 150, second: 130 + Double(index)))
      }

      #expect(engine.progress.distanceAlongRoute == frozen)
      #expect(engine.progress.isOffRoute)
   }

   // MARK: - Arrival

   @Test func arrivalFiresOnceAtTheRouteEnd() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(straightLine(length: 300)))

      var events = ride(into: &engine, from: 0, to: 300)
      events += engine.ingest(fix(east: 300, second: 200))
      events += engine.ingest(fix(east: 300, second: 205))

      #expect(count(of: .arrived, in: events) == 1)
      #expect(engine.progress.hasArrived)
   }

   /// A loop that passes within thirty meters of its own destination halfway round
   /// must not announce arrival there.
   @Test func passingNearTheDestinationEarlyIsNotArrival() {
      var engine = RouteGuidanceEngine()
      let line = straightLine(length: 500)
         + Array(stride(from: 500.0, through: 20, by: -20).map { point(east: $0, north: 5) })
      engine.prepare(route(line))

      let events = ride(into: &engine, from: 0, to: 100)

      #expect(count(of: .arrived, in: events) == 0)
      #expect(engine.progress.hasArrived == false)
   }

   @Test func arrivalDoesNotFireWhileOffRoute() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(straightLine(length: 300)))
      ride(into: &engine, from: 0, to: 100)

      var events: [RouteGuidanceEvent] = []
      for index in 0..<12 {
         events += engine.ingest(fix(east: 120, north: 90, second: 100 + Double(index) * 2))
      }

      // Level with the destination, but confirmed off route and not yet
      // re-acquired: this sample cannot arrive.
      events += engine.ingest(fix(east: 300, north: 90, second: 130))

      #expect(count(of: .arrived, in: events) == 0)
   }

   // MARK: - Announcements

   @Test func eachBandAnnouncesExactlyOncePerManeuver() {
      var engine = RouteGuidanceEngine()
      engine.prepare(
         route(straightLine(length: 1_600), maneuvers: [maneuver(0, "Turn left", at: 1_200)])
      )

      let events = ride(into: &engine, from: 0, to: 1_200, step: 20, speed: 5)
      let fired = cues(in: events)

      #expect(fired.allSatisfy { $0.maneuverID == 0 })

      for band in RouteGuidanceCueBand.allCases {
         #expect(fired.filter { $0.band == band }.count == 1, "band \(band.rawValue)")
      }

      #expect(fired.count == RouteGuidanceCueBand.allCases.count)
   }

   @Test func announcementsAreOrderedWidestFirst() {
      var engine = RouteGuidanceEngine()
      engine.prepare(
         route(straightLine(length: 1_600), maneuvers: [maneuver(0, "Turn left", at: 1_200)])
      )

      let fired = cues(in: ride(into: &engine, from: 0, to: 1_200, step: 20, speed: 5))

      #expect(fired.map(\.band) == [.far, .near, .imminent, .now])
   }

   /// Starting guidance twenty meters from a corner must call the corner, not
   /// recite the half-mile warning first.
   @Test func joiningCloseToATurnDoesNotStackAnnouncements() {
      var engine = RouteGuidanceEngine()
      engine.prepare(
         route(straightLine(length: 400), maneuvers: [maneuver(0, "Turn left", at: 100)])
      )

      let first = cues(in: engine.ingest(fix(east: 80, speed: 5, second: 0)))

      #expect(first.count == 1)
      #expect(first.first?.band == .imminent)

      let rest = cues(in: ride(into: &engine, from: 92, to: 100, step: 4, speed: 5, startingAtSecond: 5))

      #expect(rest.map(\.band) == [.now])
   }

   @Test func cueDistancesWidenWithSpeed() {
      let turn: CLLocationDistance = 2_000

      func distanceAtWhichNearFired(speed: Double) -> CLLocationDistance? {
         var engine = RouteGuidanceEngine()
         engine.prepare(
            route(straightLine(length: 2_600), maneuvers: [maneuver(0, "Turn left", at: turn)])
         )

         let fired = cues(in: ride(into: &engine, from: 0, to: turn, step: 20, speed: speed))
         return fired.first { $0.band == .near }?.distance
      }

      let slow = distanceAtWhichNearFired(speed: 3) ?? 0
      let fast = distanceAtWhichNearFired(speed: 12) ?? 0

      #expect(slow <= RouteGuidanceCueBand.near.baseDistance + 20)
      #expect(fast > RouteGuidanceCueBand.near.baseDistance + 40)
      #expect(fast > slow)
   }

   @Test func noCuesAreProducedWhileOffRoute() {
      var engine = RouteGuidanceEngine()
      engine.prepare(
         route(straightLine(length: 2_000), maneuvers: [maneuver(0, "Turn left", at: 1_800)])
      )
      ride(into: &engine, from: 0, to: 200)

      var events: [RouteGuidanceEvent] = []
      for index in 0..<12 {
         events += engine.ingest(fix(east: 220, north: 90, second: 100 + Double(index) * 2))
      }

      let afterDeparture = events.drop { $0 != .departedRoute }
      #expect(cues(in: Array(afterDeparture)).isEmpty)
   }

   @Test func aFreshRouteAnnouncesItsTurnsAgain() {
      var engine = RouteGuidanceEngine()
      let plan = route(
         straightLine(length: 400),
         maneuvers: [maneuver(0, "Turn left", at: 200)]
      )

      engine.prepare(plan)
      let first = cues(in: ride(into: &engine, from: 0, to: 200, step: 20, speed: 5))
      #expect(!first.isEmpty)

      engine.prepare(plan)
      let second = cues(in: ride(into: &engine, from: 0, to: 200, step: 20, speed: 5))

      #expect(second.map(\.band) == first.map(\.band))
   }

   // MARK: - Estimates

   @Test func theArrivalEstimateUsesASpeedFloorWhenStopped() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(straightLine(length: 1_000)))

      _ = engine.ingest(fix(east: 0, speed: 0, second: 0))

      // 1,000 m at the 4 m/s floor is 250 s, rather than an infinite estimate.
      #expect(abs(engine.progress.estimatedTimeRemaining - 250) < 15)
   }

   @Test func theArrivalEstimateTightensAsTheRiderSpeedsUp() {
      var engine = RouteGuidanceEngine()
      engine.prepare(route(straightLine(length: 2_000)))

      ride(into: &engine, from: 0, to: 200, speed: 4)
      let slow = engine.progress.estimatedTimeRemaining

      ride(into: &engine, from: 220, to: 400, speed: 14, startingAtSecond: 200)
      let fast = engine.progress.estimatedTimeRemaining

      #expect(fast < slow)
   }

   // MARK: - Reset

   @Test func resetClearsEverything() {
      var engine = RouteGuidanceEngine()
      engine.prepare(
         route(straightLine(length: 1_000), maneuvers: [maneuver(0, "Turn left", at: 600)])
      )
      ride(into: &engine, from: 0, to: 400)

      engine.reset()

      #expect(engine.isReady == false)
      #expect(engine.progress == .inactive)
      #expect(engine.ingest(fix(east: 400, second: 500)).isEmpty)
   }
}
