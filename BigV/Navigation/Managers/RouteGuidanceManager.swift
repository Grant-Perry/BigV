//
//  RouteGuidanceManager.swift
//  BigV
//

import CoreLocation
import Foundation

/// Owns live guidance: feeds the engine, publishes what it decides, and handles
/// the consequences the engine deliberately refuses to — speaking, rerouting and
/// clearing the route on arrival.
///
/// Attaches where stage one said it would: `PlannedRouteManager` for the route,
/// the accepted-sample forward from `RideSessionManager` for position. Nothing in
/// the ride pipeline learns what a turn is.
///
/// Guidance runs only while a route is active *and* the ride is recording. A route
/// planned but never started draws a line and says nothing, which is the honest
/// behaviour: with no ride there is no location stream to guide from.
@Observable
@MainActor
final class RouteGuidanceManager {

   // MARK: - Tuning

   struct Configuration: Sendable {

      /// Minimum gap between reroute attempts. Long enough that a rider threading
      /// a gap in coverage does not generate a request per sample, short enough to
      /// still be useful when they really have left the route.
      var rerouteCooldown: TimeInterval = 25

      /// Consecutive failures before guidance stops asking. Telling a rider once
      /// that rerouting is not working respects them; telling them every
      /// twenty-five seconds for an hour does not.
      var maximumRerouteAttempts = 3

      static let `default` = Configuration()
   }

   private static let voicePreferenceKey = "guidance.voice.enabled"

   // MARK: - Published State

   private(set) var phase: RouteGuidancePhase = .inactive
   private(set) var progress: RouteGuidanceProgress = .inactive
   private(set) var destinationName: String?

   /// Real MapKit steps from the active route. Empty when nothing is being followed.
   var maneuvers: [PlannedRouteManeuver] {
      plannedRouteManager.activeRoute?.maneuvers ?? []
   }

   /// Bumped when a turn is close enough to be worth feeling rather than reading.
   /// The view triggers a haptic off the change; the manager stays free of UIKit.
   private(set) var turnPulse = 0

   /// Persisted across launches, because a rider who turned voice off did not
   /// mean "until the next ride".
   var isVoiceEnabled: Bool {
      get { voicePreference }
      set {
         guard newValue != voicePreference else { return }

         voicePreference = newValue
         announcer.isEnabled = newValue
         defaults.set(newValue, forKey: Self.voicePreferenceKey)

         DebugPrint(mode: .navigation, "Voice guidance \(newValue ? "on" : "off")")
      }
   }

   private var voicePreference: Bool

   // MARK: - Dependencies

   private let plannedRouteManager: PlannedRouteManager
   private let plannedRouteProvider: any PlannedRouteProviding
   private let announcer: RouteGuidanceSpeechAnnouncer
   private let defaults: UserDefaults
   private let configuration: Configuration

   private var engine: RouteGuidanceEngine

   // MARK: - Private State

   /// The route the engine is currently loaded with, so a swap is detected
   /// without comparing geometry — `CLLocationCoordinate2D` is not `Equatable`.
   private var followedRouteID: PlannedRoute.ID?

   /// A route the rider explicitly stopped following. Kept so the next accepted
   /// sample does not immediately restart guidance on the line they just dropped.
   private var suppressedRouteID: PlannedRoute.ID?

   private var latestFix: RouteGuidanceFix?

   private var rerouteGeneration = RouteRequestGeneration()
   private var rerouteTask: Task<Void, Never>?
   private var isRerouting = false
   private var rerouteFailureCount = 0
   private var lastRerouteAttemptAt: Date?

   // MARK: - Initialization

   init(
      plannedRouteManager: PlannedRouteManager = PlannedRouteManager(),
      plannedRouteProvider: any PlannedRouteProviding = MapKitCyclingRoutePlanner(),
      announcer: RouteGuidanceSpeechAnnouncer = RouteGuidanceSpeechAnnouncer(),
      configuration: Configuration = .default,
      engineConfiguration: RouteGuidanceEngine.Configuration = .default,
      defaults: UserDefaults = .standard
   ) {
      self.plannedRouteManager = plannedRouteManager
      self.plannedRouteProvider = plannedRouteProvider
      self.announcer = announcer
      self.defaults = defaults
      self.configuration = configuration
      self.engine = RouteGuidanceEngine(configuration: engineConfiguration)

      // On by default: a rider who bothered to plan a route wants to be told
      // about the turns without hunting for a switch first.
      voicePreference = defaults.object(forKey: Self.voicePreferenceKey) as? Bool ?? true
      announcer.isEnabled = voicePreference
   }

   // MARK: - Sample Intake

   /// One accepted ride sample, forwarded from `RideSessionManager`.
   ///
   /// Guidance activation is decided here rather than there: the ride pipeline
   /// hands over position and phase and learns nothing about routes.
   func follow(_ location: CLLocation, state: RideState) {
      guard state.phase == .recording else { return }

      guard let route = plannedRouteManager.activeRoute, route.isDrawable else {
         // The rider cleared the route while it was being followed.
         if followedRouteID != nil { stop() }
         return
      }

      guard suppressedRouteID != route.id else { return }

      if followedRouteID != route.id {
         begin(route, greeting: startPhrase)
      }

      guard engine.isReady else { return }

      let fix = RouteGuidanceFix(
         coordinate: location.coordinate,
         course: state.course,
         speed: state.speed,
         timestamp: location.timestamp
      )
      latestFix = fix

      let events = engine.ingest(fix)
      progress = engine.progress

      for event in events {
         handle(event)
      }

      refreshPhase()
      attemptRerouteIfNeeded()
   }

   // MARK: - Lifecycle

   /// Tears guidance down. Called when the location stream stops, so guidance and
   /// the audio session can never outlive the ride that drives them.
   func stop() {
      cancelRerouting()

      engine.reset()
      progress = .inactive
      phase = .inactive
      destinationName = nil
      followedRouteID = nil
      suppressedRouteID = nil
      latestFix = nil
      rerouteFailureCount = 0
      lastRerouteAttemptAt = nil

      announcer.silence()
   }

   /// Stops guidance without touching the ride or the drawn route.
   ///
   /// The line stays on the map — a rider who silences the turn calls often still
   /// wants to see where they were going.
   func stopFollowing() {
      let dropped = followedRouteID
      stop()
      suppressedRouteID = dropped

      DebugPrint(mode: .navigation, "Rider stopped guidance")
   }

   /// Ends navigation outright: the turn calls stop and the planned line comes
   /// off the map.
   ///
   /// The ride is deliberately untouched. Recording, the clock, the breadcrumb
   /// and the Health export all carry on — abandoning a route is not abandoning
   /// the ride, and losing a workout to a cancelled navigation would be
   /// indefensible.
   func endNavigation() {
      stopFollowing()
      plannedRouteManager.clear()

      DebugPrint(mode: .navigation, "Rider ended navigation; ride continues")
   }

   func dismissArrival() {
      guard phase == .arrived else { return }
      stop()
   }

   // MARK: - Route Activation

   private func begin(_ route: PlannedRoute, greeting: String?) {
      cancelRerouting()

      engine.prepare(route)
      progress = engine.progress
      followedRouteID = route.id
      suppressedRouteID = nil
      destinationName = plannedRouteManager.destination?.name
      rerouteFailureCount = 0
      lastRerouteAttemptAt = nil

      guard engine.isReady else {
         phase = .inactive
         DebugPrint(mode: .navigation, "Route carries no guidable geometry")
         return
      }

      phase = .guiding

      if let greeting {
         announcer.speak(greeting)
      }
   }

   private var startPhrase: String {
      guard let name = plannedRouteManager.destination?.name, !name.isEmpty else {
         return "Guidance started."
      }
      return "Guidance started to \(name)."
   }

   // MARK: - Events

   /// Every branch here runs only while a route is being followed, which is what
   /// keeps guidance silent when it is inactive.
   private func handle(_ event: RouteGuidanceEvent) {
      switch event {
         case .cue(let cue):
            announcer.speak(RouteGuidanceFormatters.spokenCue(cue))

            if cue.band == .imminent || cue.band == .now {
               turnPulse += 1
            }

         case .departedRoute:
            announcer.speak("Off route.")

         case .regainedRoute:
            cancelRerouting()
            rerouteFailureCount = 0
            announcer.speak("Back on route.")

         case .arrived:
            handleArrival()
      }
   }

   private func handleArrival() {
      announcer.speak(
         destinationName.map { "Arrived at \($0)." } ?? "Arrived."
      )

      phase = .arrived
      cancelRerouting()
      engine.reset()
      followedRouteID = nil
      suppressedRouteID = nil
      latestFix = nil

      // Following a dashed line to a place the rider is already standing is worse
      // than no line at all, so the route goes and the arrival banner takes over.
      plannedRouteManager.clear()
   }

   // MARK: - Phase

   private func refreshPhase() {
      guard phase != .arrived else { return }

      guard !isRerouting else {
         phase = .rerouting
         return
      }

      guard progress.isOffRoute else {
         phase = .guiding
         return
      }

      phase = rerouteFailureCount >= configuration.maximumRerouteAttempts
         ? .rerouteUnavailable
         : .offRoute
   }

   // MARK: - Rerouting

   /// Driven by samples rather than by a retry timer: while the rider is off
   /// route, every accepted sample is a chance to try again, and the cooldown plus
   /// the attempt cap are what keep that from becoming a request storm.
   private func attemptRerouteIfNeeded() {
      guard progress.isOffRoute,
            !isRerouting,
            rerouteFailureCount < configuration.maximumRerouteAttempts,
            let destination = plannedRouteManager.destination,
            let origin = latestFix?.coordinate
      else { return }

      if let lastRerouteAttemptAt,
         Date.now.timeIntervalSince(lastRerouteAttemptAt) < configuration.rerouteCooldown {
         return
      }

      lastRerouteAttemptAt = .now
      isRerouting = true
      phase = .rerouting
      announcer.speak("Rerouting.")

      let ticket = rerouteGeneration.issue()
      rerouteTask?.cancel()
      rerouteTask = Task { [weak self] in
         await self?.reroute(from: origin, to: destination, ticket: ticket)
      }
   }

   private func reroute(
      from origin: CLLocationCoordinate2D,
      to destination: RouteDestination,
      ticket: UInt64
   ) async {
      do {
         let routes = try await plannedRouteProvider.routes(from: origin, to: destination)

         // A slower earlier request must never overwrite a newer one, so the
         // ticket is checked before anything is published.
         guard rerouteGeneration.isCurrent(ticket) else { return }

         guard let replacement = routes.first(where: \.isDrawable) else {
            apply(rerouteFailure: .failed)
            return
         }

         isRerouting = false
         plannedRouteManager.activate(replacement, to: destination)
         begin(replacement, greeting: "Route updated.")
         refreshPhase()
      } catch {
         guard rerouteGeneration.isCurrent(ticket) else { return }
         apply(rerouteFailure: error)
      }
   }

   private func apply(rerouteFailure failure: RoutePlanningFailure) {
      isRerouting = false
      rerouteTask = nil
      rerouteFailureCount += 1

      DebugPrint(
         mode: .navigation,
         "Reroute failed (\(failure.rawValue)), attempt \(rerouteFailureCount) of \(configuration.maximumRerouteAttempts)"
      )

      guard rerouteFailureCount >= configuration.maximumRerouteAttempts else {
         refreshPhase()
         return
      }

      phase = .rerouteUnavailable
      announcer.speak("Could not find a new route. Head back to the route.")
   }

   private func cancelRerouting() {
      rerouteTask?.cancel()
      rerouteTask = nil
      rerouteGeneration.retireAll()
      plannedRouteProvider.cancel()
      isRerouting = false
   }
}
