//
//  RouteGuidanceManagerTests.swift
//  BigVTests
//

import CoreLocation
import Testing
@testable import BigV

@MainActor
struct RouteGuidanceManagerTests {

   // MARK: - Fixtures

   private static let origin = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
   private static let reference = Date(timeIntervalSince1970: 1_000_000)

   private func point(east: Double, north: Double = 0) -> CLLocationCoordinate2D {
      RouteGuidanceTestGeography.coordinate(east: east, north: north, from: Self.origin)
   }

   private func straightRoute(length: Double, north: Double = 0) -> PlannedRoute {
      PlannedRoute(
         id: UUID(),
         source: .appleMaps,
         name: "Test Route",
         coordinates: stride(from: 0, through: length, by: 20).map { point(east: $0, north: north) },
         distance: 0,
         expectedTravelTime: 0,
         maneuvers: [],
         advisories: []
      )
   }

   private var destination: RouteDestination {
      RouteDestination(name: "The Coffee Place", coordinate: point(east: 1_000))
   }

   private func location(east: Double, north: Double = 0, second: TimeInterval) -> CLLocation {
      CLLocation(
         coordinate: point(east: east, north: north),
         altitude: 0,
         horizontalAccuracy: 5,
         verticalAccuracy: 5,
         course: 90,
         courseAccuracy: 5,
         speed: 6,
         speedAccuracy: 1,
         timestamp: Self.reference.addingTimeInterval(second)
      )
   }

   private func state(_ phase: RidePhase = .recording) -> RideState {
      var state = RideState()
      state.phase = phase
      state.speed = 6
      state.course = 90
      state.hasGPSFix = true
      return state
   }

   /// A manager wired to fakes, with voice off so no test ever touches the audio
   /// session or the speech synthesizer.
   private func makeManager(
      planner: FakeRoutePlanner,
      plannedRouteManager: PlannedRouteManager,
      configuration: RouteGuidanceManager.Configuration = .default
   ) -> RouteGuidanceManager {
      let manager = RouteGuidanceManager(
         plannedRouteManager: plannedRouteManager,
         plannedRouteProvider: planner,
         announcer: RouteGuidanceSpeechAnnouncer(),
         configuration: configuration,
         defaults: scratchDefaults()
      )
      manager.isVoiceEnabled = false
      return manager
   }

   private func scratchDefaults() -> UserDefaults {
      UserDefaults(suiteName: "com.bigv.tests.guidance.\(UUID().uuidString)") ?? .standard
   }

   /// Lets an in-flight reroute task run to completion.
   private func settle() async {
      for _ in 0..<40 {
         await Task.yield()
      }
   }

   /// Rides east feeding the manager, one sample per `interval` seconds.
   private func ride(
      _ manager: RouteGuidanceManager,
      from start: Double,
      to end: Double,
      step: Double = 20,
      north: Double = 0,
      interval: TimeInterval = 3,
      startingAtSecond: TimeInterval = 0
   ) {
      var east = start
      var second = startingAtSecond

      while east <= end + 0.001 {
         manager.follow(location(east: east, north: north, second: second), state: state())
         east += step
         second += interval
      }
   }

   /// Sits still well off the line for long enough to confirm a departure.
   private func strayOffRoute(
      _ manager: RouteGuidanceManager,
      east: Double,
      startingAtSecond: TimeInterval
   ) {
      for index in 0..<12 {
         manager.follow(
            location(east: east, north: 90, second: startingAtSecond + Double(index) * 2),
            state: state()
         )
      }
   }

   // MARK: - Activation

   @Test func guidanceStaysInactiveWithoutARoute() {
      let plannedRouteManager = PlannedRouteManager()
      let manager = makeManager(planner: FakeRoutePlanner(), plannedRouteManager: plannedRouteManager)

      ride(manager, from: 0, to: 100)

      #expect(manager.phase == .inactive)
      #expect(manager.progress == .inactive)
   }

   @Test func guidanceStaysInactiveUntilTheRideIsRecording() {
      let plannedRouteManager = PlannedRouteManager()
      plannedRouteManager.activate(straightRoute(length: 1_000), to: destination)
      let manager = makeManager(planner: FakeRoutePlanner(), plannedRouteManager: plannedRouteManager)

      manager.follow(location(east: 0, second: 0), state: state(.acquiringGPS))
      manager.follow(location(east: 20, second: 3), state: state(.paused))

      #expect(manager.phase == .inactive)
   }

   @Test func guidanceStartsOnTheFirstRecordingSample() {
      let plannedRouteManager = PlannedRouteManager()
      plannedRouteManager.activate(straightRoute(length: 1_000), to: destination)
      let manager = makeManager(planner: FakeRoutePlanner(), plannedRouteManager: plannedRouteManager)

      ride(manager, from: 0, to: 100)

      #expect(manager.phase == .guiding)
      #expect(manager.destinationName == "The Coffee Place")
      #expect(manager.progress.isTracking)
      #expect(abs(manager.progress.distanceAlongRoute - 100) < 12)
   }

   @Test func aRouteWithNoGuidableGeometryDoesNotStartGuidance() {
      let plannedRouteManager = PlannedRouteManager()
      let flat = PlannedRoute(
         id: UUID(),
         source: .appleMaps,
         name: "",
         coordinates: Array(repeating: point(east: 0), count: 5),
         distance: 0,
         expectedTravelTime: 0,
         maneuvers: [],
         advisories: []
      )
      plannedRouteManager.activate(flat, to: destination)
      let manager = makeManager(planner: FakeRoutePlanner(), plannedRouteManager: plannedRouteManager)

      ride(manager, from: 0, to: 100)

      #expect(manager.phase == .inactive)
   }

   // MARK: - Teardown

   @Test func clearingTheRouteMidGuidanceStopsGuidance() {
      let plannedRouteManager = PlannedRouteManager()
      plannedRouteManager.activate(straightRoute(length: 1_000), to: destination)
      let manager = makeManager(planner: FakeRoutePlanner(), plannedRouteManager: plannedRouteManager)

      ride(manager, from: 0, to: 100)
      #expect(manager.phase == .guiding)

      plannedRouteManager.clear()
      ride(manager, from: 120, to: 140, startingAtSecond: 100)

      #expect(manager.phase == .inactive)
      #expect(manager.progress == .inactive)
   }

   /// Silencing the turn calls must leave the line on the map, and must not be
   /// undone by the very next GPS sample.
   @Test func stoppingGuidanceKeepsTheRouteAndDoesNotRestart() {
      let plannedRouteManager = PlannedRouteManager()
      plannedRouteManager.activate(straightRoute(length: 1_000), to: destination)
      let manager = makeManager(planner: FakeRoutePlanner(), plannedRouteManager: plannedRouteManager)

      ride(manager, from: 0, to: 100)
      manager.stopFollowing()

      ride(manager, from: 120, to: 200, startingAtSecond: 100)

      #expect(manager.phase == .inactive)
      #expect(plannedRouteManager.hasActiveRoute)
   }

   @Test func activatingANewRouteResumesGuidanceAfterStopping() {
      let plannedRouteManager = PlannedRouteManager()
      plannedRouteManager.activate(straightRoute(length: 1_000), to: destination)
      let manager = makeManager(planner: FakeRoutePlanner(), plannedRouteManager: plannedRouteManager)

      ride(manager, from: 0, to: 100)
      manager.stopFollowing()
      ride(manager, from: 120, to: 140, startingAtSecond: 100)
      #expect(manager.phase == .inactive)

      plannedRouteManager.activate(straightRoute(length: 1_000), to: destination)
      ride(manager, from: 160, to: 200, startingAtSecond: 200)

      #expect(manager.phase == .guiding)
   }

   @Test func stopClearsEverything() {
      let plannedRouteManager = PlannedRouteManager()
      plannedRouteManager.activate(straightRoute(length: 1_000), to: destination)
      let manager = makeManager(planner: FakeRoutePlanner(), plannedRouteManager: plannedRouteManager)

      ride(manager, from: 0, to: 100)
      manager.stop()

      #expect(manager.phase == .inactive)
      #expect(manager.progress == .inactive)
      #expect(manager.destinationName == nil)
   }

   // MARK: - Arrival

   @Test func arrivalClearsTheRouteAndHoldsTheArrivedState() {
      let plannedRouteManager = PlannedRouteManager()
      plannedRouteManager.activate(straightRoute(length: 200), to: destination)
      let manager = makeManager(planner: FakeRoutePlanner(), plannedRouteManager: plannedRouteManager)

      ride(manager, from: 0, to: 200)

      #expect(manager.phase == .arrived)
      #expect(manager.progress.hasArrived)
      #expect(plannedRouteManager.hasActiveRoute == false)

      // Later samples must not knock the arrival banner off the screen.
      ride(manager, from: 220, to: 260, startingAtSecond: 200)
      #expect(manager.phase == .arrived)
   }

   @Test func dismissingArrivalReturnsToInactive() {
      let plannedRouteManager = PlannedRouteManager()
      plannedRouteManager.activate(straightRoute(length: 200), to: destination)
      let manager = makeManager(planner: FakeRoutePlanner(), plannedRouteManager: plannedRouteManager)

      ride(manager, from: 0, to: 200)
      manager.dismissArrival()

      #expect(manager.phase == .inactive)
      #expect(manager.progress == .inactive)
   }

   // MARK: - Rerouting

   @Test func aConfirmedDepartureAsksForANewRoute() async {
      let planner = FakeRoutePlanner()
      planner.result = .failure(.offline)

      let plannedRouteManager = PlannedRouteManager()
      plannedRouteManager.activate(straightRoute(length: 2_000), to: destination)
      let manager = makeManager(planner: planner, plannedRouteManager: plannedRouteManager)

      ride(manager, from: 0, to: 200)
      strayOffRoute(manager, east: 220, startingAtSecond: 100)
      await settle()

      #expect(manager.progress.isOffRoute)
      #expect(planner.requestCount == 1)
      #expect(manager.phase == .offRoute)
   }

   @Test func aSuccessfulRerouteSwapsTheActiveRoute() async {
      let planner = FakeRoutePlanner()
      let replacement = straightRoute(length: 900, north: 90)
      planner.result = .success([replacement])

      let plannedRouteManager = PlannedRouteManager()
      plannedRouteManager.activate(straightRoute(length: 2_000), to: destination)
      let manager = makeManager(planner: planner, plannedRouteManager: plannedRouteManager)

      ride(manager, from: 0, to: 200)
      strayOffRoute(manager, east: 220, startingAtSecond: 100)
      await settle()

      #expect(plannedRouteManager.activeRoute?.id == replacement.id)
      #expect(manager.phase == .guiding)
      #expect(manager.progress.isOffRoute == false)
   }

   /// A rider threading a gap in coverage generates a deviating sample every
   /// second. The cooldown is what stops that becoming a request per second.
   @Test func rerouteAttemptsAreRateLimited() async {
      let planner = FakeRoutePlanner()
      planner.result = .failure(.offline)

      let plannedRouteManager = PlannedRouteManager()
      plannedRouteManager.activate(straightRoute(length: 4_000), to: destination)
      let manager = makeManager(planner: planner, plannedRouteManager: plannedRouteManager)

      ride(manager, from: 0, to: 200)
      strayOffRoute(manager, east: 220, startingAtSecond: 100)
      await settle()
      #expect(planner.requestCount == 1)

      // Sixty more deviating samples, all inside the cooldown.
      for index in 0..<60 {
         manager.follow(
            location(east: 400, north: 120, second: 200 + Double(index)),
            state: state()
         )
         await settle()
      }

      #expect(planner.requestCount == 1)
   }

   @Test func repeatedRerouteFailuresStopTheAsking() async {
      let planner = FakeRoutePlanner()
      planner.result = .failure(.noCyclingRoute)

      let plannedRouteManager = PlannedRouteManager()
      plannedRouteManager.activate(straightRoute(length: 4_000), to: destination)
      let manager = makeManager(
         planner: planner,
         plannedRouteManager: plannedRouteManager,
         configuration: RouteGuidanceManager.Configuration(
            rerouteCooldown: 0,
            maximumRerouteAttempts: 3
         )
      )

      ride(manager, from: 0, to: 200)
      strayOffRoute(manager, east: 220, startingAtSecond: 100)
      await settle()

      for index in 0..<10 {
         manager.follow(
            location(east: 400, north: 120, second: 200 + Double(index)),
            state: state()
         )
         await settle()
      }

      #expect(planner.requestCount == 3)
      #expect(manager.phase == .rerouteUnavailable)
   }

   @Test func regainingTheRouteLetsGuidanceAskAgain() async {
      let planner = FakeRoutePlanner()
      planner.result = .failure(.noCyclingRoute)

      let plannedRouteManager = PlannedRouteManager()
      plannedRouteManager.activate(straightRoute(length: 4_000), to: destination)
      let manager = makeManager(
         planner: planner,
         plannedRouteManager: plannedRouteManager,
         configuration: RouteGuidanceManager.Configuration(
            rerouteCooldown: 0,
            maximumRerouteAttempts: 2
         )
      )

      ride(manager, from: 0, to: 200)
      strayOffRoute(manager, east: 220, startingAtSecond: 100)
      for index in 0..<6 {
         manager.follow(
            location(east: 400, north: 120, second: 200 + Double(index)),
            state: state()
         )
         await settle()
      }
      #expect(manager.phase == .rerouteUnavailable)

      // Back on the line for three samples.
      ride(manager, from: 420, to: 460, startingAtSecond: 300)
      await settle()

      #expect(manager.phase == .guiding)
      #expect(manager.progress.isOffRoute == false)
   }

   /// The ticket pattern: an answer from a request guidance has moved on from must
   /// never be published.
   @Test func aStaleRerouteAnswerCannotClobberANewerOne() async {
      let planner = FakeRoutePlanner()
      let stale = straightRoute(length: 900, north: 200)
      planner.result = .success([stale])
      planner.holdsUntilReleased = true

      let plannedRouteManager = PlannedRouteManager()
      let original = straightRoute(length: 4_000)
      plannedRouteManager.activate(original, to: destination)
      let manager = makeManager(planner: planner, plannedRouteManager: plannedRouteManager)

      ride(manager, from: 0, to: 200)
      strayOffRoute(manager, east: 220, startingAtSecond: 100)
      await settle()
      #expect(planner.requestCount == 1)

      // The rider silences guidance while the request is still in flight, which
      // retires every outstanding ticket.
      manager.stopFollowing()
      planner.release()
      await settle()

      #expect(plannedRouteManager.activeRoute?.id == original.id)
      #expect(manager.phase == .inactive)
   }

   // MARK: - Voice Preference

   @Test func theVoicePreferenceIsPersisted() {
      let defaults = scratchDefaults()
      let plannedRouteManager = PlannedRouteManager()

      let first = RouteGuidanceManager(
         plannedRouteManager: plannedRouteManager,
         plannedRouteProvider: FakeRoutePlanner(),
         defaults: defaults
      )
      #expect(first.isVoiceEnabled)

      first.isVoiceEnabled = false

      let second = RouteGuidanceManager(
         plannedRouteManager: plannedRouteManager,
         plannedRouteProvider: FakeRoutePlanner(),
         defaults: defaults
      )

      #expect(second.isVoiceEnabled == false)
   }
}

// MARK: - Fake Planner

/// A route provider that answers from a script instead of the network.
@MainActor
private final class FakeRoutePlanner: PlannedRouteProviding {

   var result: Result<[PlannedRoute], RoutePlanningFailure> = .success([])

   /// Holds the answer back so a test can decide what happens while a request is
   /// still in flight.
   var holdsUntilReleased = false

   private(set) var requestCount = 0
   private(set) var cancelCount = 0

   private var isReleased = false

   func release() {
      isReleased = true
   }

   func routes(
      from origin: CLLocationCoordinate2D,
      to destination: RouteDestination
   ) async throws(RoutePlanningFailure) -> [PlannedRoute] {
      requestCount += 1

      if holdsUntilReleased {
         while !isReleased {
            await Task.yield()
         }
      }

      switch result {
         case .success(let routes): return routes
         case .failure(let failure): throw failure
      }
   }

   func cancel() {
      cancelCount += 1
   }
}
