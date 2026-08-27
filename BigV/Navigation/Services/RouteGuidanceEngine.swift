//
//  RouteGuidanceEngine.swift
//  BigV
//

import CoreLocation
import Foundation

/// Turns a planned route plus a stream of rider positions into turn-by-turn
/// guidance.
///
/// Apple hands third parties a polyline and some instruction text. There is no
/// voice engine, no progress tracking, no off-route detection and no rerouting —
/// all of that is this file and the session that owns it.
///
/// Pure math with no framework side effects, deliberately mirroring
/// `RideTelemetryEngine`: it speaks nothing, draws nothing and asks nobody for a
/// route. It ingests a fix, updates its own scalars, and *reports* what it
/// decided. Everything trust-critical about guidance is therefore reachable from
/// a synchronous test.
///
/// The whole design rests on one number: progress along the route as a single
/// scalar. Once that is known, "which turn is next" and "how far to it" are a
/// subtraction against `PlannedRouteManeuver.distanceFromStart`, not a geometry
/// search per GPS sample.
struct RouteGuidanceEngine {

   // MARK: - Configuration

   struct Configuration: Sendable {

      /// Lateral meters from the line before a sample counts as deviating.
      /// Comfortably past both a parallel service road and typical urban GPS
      /// error, so a rider who is genuinely on the route never trips it.
      var offRouteDistance: CLLocationDistance = 40

      /// Lateral meters a sample must be *within* to count as back on the line.
      /// The gap between this and `offRouteDistance` is the hysteresis: no single
      /// noisy sample can carry the state across both thresholds.
      var onRouteDistance: CLLocationDistance = 25

      /// Consecutive deviating samples required before off-route is declared.
      var offRouteConfirmationSamples: Int = 5

      /// Seconds of unbroken deviation required before off-route is declared.
      /// Enforced alongside the sample count so a burst of fast samples cannot
      /// confirm a deviation the rider had no time to make.
      var offRouteConfirmationInterval: TimeInterval = 12

      /// Consecutive re-acquired samples required before off-route clears.
      var onRouteConfirmationSamples: Int = 3

      /// Meters from the route end that counts as having arrived.
      var arrivalRadius: CLLocationDistance = 30

      /// Arrival also requires the route to be nearly used up, so a loop that
      /// passes its own destination mid-ride does not announce arrival early.
      var arrivalApproachDistance: CLLocationDistance = 120

      /// How far behind current progress the per-sample search looks. Enough for
      /// a rider who overshot a turn and backed up, far too little to snap to an
      /// unrelated part of the route.
      var trackingWindowBehind: CLLocationDistance = 60

      /// How far ahead the per-sample search looks. A bicycle covers well under
      /// this between samples even at racing speed.
      var trackingWindowAhead: CLLocationDistance = 250

      /// Meters past a maneuver before it stops being the upcoming one.
      var maneuverPassedTolerance: CLLocationDistance = 8

      /// Floor under the speed used for arrival estimates and cue distances, so a
      /// rider stopped at a light neither sees an infinite ETA nor loses their
      /// early turn warning. 4 m/s is about 9 mph.
      var minimumPaceSpeed: Double = 4

      var paceSmoothingFactor: Double = 0.3

      /// Speed at or above which the rider counts as moving, matching
      /// `RideTelemetryEngine`.
      var movingSpeedThreshold: Double = 0.9

      /// Meters of retraced route required before the rider is called out as
      /// travelling the route backwards.
      var againstRouteDistance: CLLocationDistance = 25

      var againstRouteSamples: Int = 3

      static let `default` = Configuration()
   }

   // MARK: - Published State

   private(set) var progress: RouteGuidanceProgress = .inactive

   /// Whether a usable route is loaded. A route of nought or one coordinate, or
   /// one whose points are all the same place, is not guidable and is refused
   /// here rather than producing nonsense downstream.
   var isReady: Bool { coordinates.count > 1 && geometryLength > 0 }

   // MARK: - Private Configuration

   private let configuration: Configuration

   // MARK: - Route

   private var coordinates: [CLLocationCoordinate2D] = []
   private var cumulative: [CLLocationDistance] = []
   private var maneuvers: [PlannedRouteManeuver] = []
   private var endCoordinate: CLLocationCoordinate2D?

   private var geometryLength: CLLocationDistance = 0
   private var routeDistance: CLLocationDistance = 0

   /// Converts progress along the drawn geometry into the provider's distance
   /// space, which is the space maneuver offsets are measured in.
   private var distanceScale: Double = 1

   // MARK: - Private Tracking State

   private var isLocated = false
   private var geometryProgress: CLLocationDistance = 0
   private var lateralDeviation: CLLocationDistance = 0
   private var paceSpeed: Double = 0

   private var deviationStreak = 0
   private var deviationStartedAt: Date?
   private var recoveryStreak = 0
   private var isOffRoute = false

   private var againstRouteStreak = 0
   private var againstRouteRun: CLLocationDistance = 0
   private var isAgainstRoute = false

   private var hasArrived = false

   /// Bands already fired for each maneuver, keyed by maneuver id. This is what
   /// makes an announcement happen exactly once: nothing un-latches within a
   /// route, and a reroute produces a new route and a fresh table.
   private var latchedBands: [PlannedRouteManeuver.ID: Set<RouteGuidanceCueBand>] = [:]

   // MARK: - Initialization

   init(configuration: Configuration = .default) {
      self.configuration = configuration
   }

   // MARK: - Route Lifecycle

   /// Loads a route and discards everything known about the previous one.
   mutating func prepare(_ route: PlannedRoute) {
      reset()

      let usable = route.coordinates.filter(RideRouteDownsampler.isUsable)
      guard usable.count > 1 else { return }

      let distances = RouteGuidanceGeometry.cumulativeDistances(for: usable)
      guard let length = distances.last, length > 0 else { return }

      coordinates = usable
      cumulative = distances
      geometryLength = length
      endCoordinate = usable.last

      // Sorted because guidance finds the next turn by walking offsets forward,
      // and no provider promises its steps arrive in order.
      maneuvers = route.maneuvers.sorted { $0.distanceFromStart < $1.distanceFromStart }

      routeDistance = route.distance.isFinite && route.distance > 0 ? route.distance : length

      // A provider's total and the length of the line it drew rarely agree
      // exactly. Scaling progress into the provider's space keeps distance-to-turn
      // honest rather than letting the difference accumulate over a long route.
      let ratio = routeDistance / length
      distanceScale = (0.5...2).contains(ratio) ? ratio : 1

      DebugPrint(
         mode: .navigation,
         "Guidance prepared: \(usable.count) points, \(length) m drawn, \(routeDistance) m claimed, \(maneuvers.count) maneuvers"
      )
   }

   mutating func reset() {
      progress = .inactive
      coordinates = []
      cumulative = []
      maneuvers = []
      endCoordinate = nil
      geometryLength = 0
      routeDistance = 0
      distanceScale = 1
      isLocated = false
      geometryProgress = 0
      lateralDeviation = 0
      paceSpeed = 0
      deviationStreak = 0
      deviationStartedAt = nil
      recoveryStreak = 0
      isOffRoute = false
      againstRouteStreak = 0
      againstRouteRun = 0
      isAgainstRoute = false
      hasArrived = false
      latchedBands.removeAll(keepingCapacity: true)
   }

   // MARK: - Ingestion

   /// Folds one rider position into the guidance state.
   ///
   /// Returns everything that changed and is worth acting on. An empty array is
   /// the common case and means "keep doing what you were doing".
   mutating func ingest(_ fix: RouteGuidanceFix) -> [RouteGuidanceEvent] {
      guard isReady, RideRouteDownsampler.isUsable(fix.coordinate) else { return [] }

      updatePace(with: fix.speed)

      guard let projection = locate(fix) else { return [] }

      var events: [RouteGuidanceEvent] = []
      lateralDeviation = projection.lateralDistance

      if isOffRoute {
         events.append(contentsOf: evaluateRecovery(projection))
      } else {
         commit(projection, isMoving: fix.speed >= configuration.movingSpeedThreshold)
         events.append(contentsOf: evaluateDeviation(projection, at: fix.timestamp))
      }

      let routeProgress = min(routeDistance, max(0, geometryProgress * distanceScale))
      let remaining = max(0, routeDistance - routeProgress)

      if let arrival = evaluateArrival(fix, remaining: remaining) {
         events.append(arrival)
      }

      let upcomingIndex = maneuvers.firstIndex {
         $0.distanceFromStart + configuration.maneuverPassedTolerance > routeProgress
      }
      let upcoming = upcomingIndex.map { maneuvers[$0] }
      let distanceToUpcoming = upcoming.map { max(0, $0.distanceFromStart - routeProgress) }

      if !isOffRoute, !hasArrived,
         let upcoming, let distanceToUpcoming,
         let cue = cue(for: upcoming, distance: distanceToUpcoming) {
         events.append(.cue(cue))
      }

      progress = RouteGuidanceProgress(
         isTracking: isLocated,
         distanceAlongRoute: routeProgress,
         distanceRemaining: remaining,
         lateralDeviation: lateralDeviation,
         estimatedTimeRemaining: remaining / max(paceSpeed, configuration.minimumPaceSpeed),
         upcomingManeuverID: upcoming?.id,
         upcomingInstruction: upcoming?.instruction,
         upcomingNotice: upcoming?.notice,
         distanceToUpcomingManeuver: distanceToUpcoming,
         followingInstruction: upcomingIndex.flatMap(followingInstruction),
         isOffRoute: isOffRoute,
         isAgainstRoute: isAgainstRoute,
         hasArrived: hasArrived
      )

      return events
   }

   // MARK: - Locating

   /// While tracking, the search is confined to a window around current progress
   /// — the single most important defence against a doubled-back route, because a
   /// stretch of line 800 m away is never a candidate no matter how close it
   /// looks. Once off route the window is dropped, since re-acquiring means
   /// finding the rider wherever on the route they rejoined.
   private func locate(_ fix: RouteGuidanceFix) -> RouteGuidanceGeometry.Projection? {
      let isWindowed = isLocated && !isOffRoute

      let range = isWindowed
         ? RouteGuidanceGeometry.segmentRange(
            from: geometryProgress - configuration.trackingWindowBehind,
            to: geometryProgress + configuration.trackingWindowAhead,
            cumulative: cumulative
         )
         : 0..<max(1, coordinates.count - 1)

      return RouteGuidanceGeometry.locate(
         fix.coordinate,
         on: coordinates,
         cumulative: cumulative,
         in: range,
         course: fix.course,
         anchor: isWindowed ? geometryProgress : nil
      )
   }

   private mutating func commit(
      _ projection: RouteGuidanceGeometry.Projection,
      isMoving: Bool
   ) {
      let delta = isLocated ? projection.distanceAlongRoute - geometryProgress : 0

      geometryProgress = projection.distanceAlongRoute
      isLocated = true

      updateDirection(delta: delta, isMoving: isMoving)
   }

   // MARK: - Direction Of Travel

   /// A rider retracing the route has every instruction behind them, so it is
   /// worth stating rather than silently pointing them at turns they already
   /// made. Cleared by the first real forward progress.
   private mutating func updateDirection(delta: CLLocationDistance, isMoving: Bool) {
      guard isMoving else { return }

      if delta < -1 {
         againstRouteStreak += 1
         againstRouteRun -= delta
      } else if delta > 1 {
         againstRouteStreak = 0
         againstRouteRun = 0
      }

      isAgainstRoute = againstRouteStreak >= configuration.againstRouteSamples
         && againstRouteRun >= configuration.againstRouteDistance
   }

   // MARK: - Off Route

   private mutating func evaluateDeviation(
      _ projection: RouteGuidanceGeometry.Projection,
      at timestamp: Date
   ) -> [RouteGuidanceEvent] {
      let deviation = projection.lateralDistance

      if deviation > configuration.offRouteDistance {
         if deviationStartedAt == nil { deviationStartedAt = timestamp }
         deviationStreak += 1
      } else if deviation <= configuration.onRouteDistance {
         deviationStreak = 0
         deviationStartedAt = nil
      }

      guard deviationStreak >= configuration.offRouteConfirmationSamples,
            let startedAt = deviationStartedAt,
            timestamp.timeIntervalSince(startedAt) >= configuration.offRouteConfirmationInterval
      else { return [] }

      isOffRoute = true
      recoveryStreak = 0

      DebugPrint(
         mode: .navigation,
         "Off route confirmed: \(deviation) m from the line for \(timestamp.timeIntervalSince(startedAt)) s"
      )

      return [.departedRoute]
   }

   private mutating func evaluateRecovery(
      _ projection: RouteGuidanceGeometry.Projection
   ) -> [RouteGuidanceEvent] {
      // Progress is deliberately frozen while off route: a global search from
      // 300 m away lands somewhere real but arbitrary, and sliding the banner
      // between unrelated turns is worse than showing the last thing known.
      guard projection.lateralDistance <= configuration.onRouteDistance else {
         recoveryStreak = 0
         return []
      }

      recoveryStreak += 1
      guard recoveryStreak >= configuration.onRouteConfirmationSamples else { return [] }

      isOffRoute = false
      recoveryStreak = 0
      deviationStreak = 0
      deviationStartedAt = nil
      againstRouteStreak = 0
      againstRouteRun = 0
      isAgainstRoute = false

      geometryProgress = projection.distanceAlongRoute
      isLocated = true

      DebugPrint(mode: .navigation, "Back on route at \(geometryProgress) m along")

      return [.regainedRoute]
   }

   // MARK: - Arrival

   private mutating func evaluateArrival(
      _ fix: RouteGuidanceFix,
      remaining: CLLocationDistance
   ) -> RouteGuidanceEvent? {
      guard !hasArrived, !isOffRoute, let endCoordinate else { return nil }

      let toEnd = RideRouteDownsampler.meters(from: fix.coordinate, to: endCoordinate)

      guard toEnd <= configuration.arrivalRadius,
            remaining <= configuration.arrivalApproachDistance
      else { return nil }

      hasArrived = true

      DebugPrint(mode: .navigation, "Arrived: \(toEnd) m from the route end")

      return .arrived
   }

   // MARK: - Cues

   /// The one band worth speaking this sample, or nothing.
   ///
   /// Every band the rider is already inside is latched, but only the tightest
   /// newly-crossed one is returned. That is what stops four announcements
   /// stacking when guidance starts twenty meters from a corner, and what
   /// guarantees a given band fires once per maneuver and never again.
   private mutating func cue(
      for maneuver: PlannedRouteManeuver,
      distance: CLLocationDistance
   ) -> RouteGuidanceCue? {
      let alreadyFired = latchedBands[maneuver.id] ?? []
      var latched = alreadyFired
      var tightest: RouteGuidanceCueBand?

      for band in RouteGuidanceCueBand.widestFirst
      where distance <= band.triggerDistance(atSpeed: paceSpeed) {
         tightest = band
         latched.insert(band)
      }

      latchedBands[maneuver.id] = latched

      guard let tightest, !alreadyFired.contains(tightest) else { return nil }

      return RouteGuidanceCue(
         maneuverID: maneuver.id,
         band: tightest,
         instruction: maneuver.instruction,
         distance: distance
      )
   }

   // MARK: - Pace

   private mutating func updatePace(with speed: Double) {
      let plausible = max(0, speed)

      paceSpeed = paceSpeed == 0
         ? plausible
         : paceSpeed + (plausible - paceSpeed) * configuration.paceSmoothingFactor
   }

   // MARK: - Instructions

   private func followingInstruction(after index: Int) -> String? {
      let next = index + 1
      guard next < maneuvers.count else { return nil }
      return maneuvers[next].instruction
   }
}
