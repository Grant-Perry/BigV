//
//  RideClimbModel.swift
//  BigV
//

import Foundation
import Observation

/// The climb feature's single source of truth: what is left to climb, what is
/// being climbed right now, and when a climb worth looking at begins.
///
/// Owned by the app and injected through the environment like the weather
/// model — not nested under `RideViewModel`, because climbs outlive any one
/// view and both the climb page and the dashboard tile read the same snapshot.
///
/// It reads guidance progress and ride state on a one-second cadence — the
/// same rate GPS feeds everything else — and publishes one `ClimbProgress`.
/// Forward-looking numbers exist only while a route with an elevation profile
/// is being tracked; freeride gets the live detector's climb-so-far and
/// nothing invented.
@Observable
@MainActor
final class RideClimbModel {

   // MARK: - Published State

   /// The route-based climb picture. `.none` on freeride and before START.
   private(set) var progress: ClimbProgress = .none

   /// The climb underway from telemetry alone, route or not.
   private(set) var liveClimb: LiveClimbDetector.Status = .idle

   /// Bumped when a categorized climb begins while recording. The pager's
   /// auto-switch trigger, monotonic for the same reason radar pulses are.
   private(set) var climbStartPulse = 0

   // MARK: - Dependencies

   /// All optional so previews and tests can build the model with no session
   /// behind it, matching `RideDetailViewModel`.
   @ObservationIgnored private let rideSessionManager: RideSessionManager?
   @ObservationIgnored private let routeGuidanceManager: RouteGuidanceManager?
   @ObservationIgnored private let plannedRouteManager: PlannedRouteManager?
   @ObservationIgnored private let climbSettings: RideClimbSettings
   @ObservationIgnored private let unitsSettings: RideUnitsSettings

   // MARK: - Private State

   @ObservationIgnored private var progressEngine = ClimbProgressEngine()
   @ObservationIgnored private var liveDetector = LiveClimbDetector()

   /// Identity of the route the progress engine is prepared with, plus its
   /// profile size — enrichment can land on the same route id later.
   @ObservationIgnored private var preparedRouteID: PlannedRoute.ID?
   @ObservationIgnored private var preparedProfileCount = 0

   /// Where the rider was when the active planned climb began, so the split
   /// records their telemetry rather than the profile's promise.
   @ObservationIgnored private var plannedClimbAnchor: ClimbAnchor?

   @ObservationIgnored private var lastPhase: RidePhase = .idle

   private struct ClimbAnchor {
      let climb: PlannedClimb
      let startedAt: Date
      let startDistance: Double
   }

   // MARK: - Initialization

   init(
      rideSessionManager: RideSessionManager? = nil,
      routeGuidanceManager: RouteGuidanceManager? = nil,
      plannedRouteManager: PlannedRouteManager? = nil,
      climbSettings: RideClimbSettings = RideClimbSettings(),
      unitsSettings: RideUnitsSettings = RideUnitsSettings()
   ) {
      self.rideSessionManager = rideSessionManager
      self.routeGuidanceManager = routeGuidanceManager
      self.plannedRouteManager = plannedRouteManager
      self.climbSettings = climbSettings
      self.unitsSettings = unitsSettings
   }

   // MARK: - Derived

   var unitSystem: RideUnitSystem { unitsSettings.system }

   var isAutoSwitchEnabled: Bool { climbSettings.autoSwitchEnabled }

   var state: RideState { rideSessionManager?.state ?? RideState() }

   /// The active route's profile, for the page's charts. Empty on freeride.
   var routeProfile: [RouteElevationSample] {
      plannedRouteManager?.activeRoute?.elevationProfile ?? []
   }

   var routeClimbs: [PlannedClimb] {
      plannedRouteManager?.activeRoute?.climbs ?? []
   }

   // MARK: - Refresh Loop

   /// Driven by the root view's `task`, so it lives for the app's life and
   /// climb splits are cut even while the rider reads another tab.
   func run() async {
      while !Task.isCancelled {
         refresh()
         try? await Task.sleep(for: .seconds(1))
      }
   }

   /// One pass of the whole climb picture. Internal so tests can step it.
   func refresh() {
      guard let rideSessionManager else { return }

      let rideState = rideSessionManager.state
      syncRideLifecycle(rideState.phase)
      syncRoute()
      refreshProgress(with: rideState)
      feedLiveDetector(with: rideState)
   }

   // MARK: - Lifecycle Sync

   /// A new ride starts every accumulator over; a finished one clears the page.
   private func syncRideLifecycle(_ phase: RidePhase) {
      defer { lastPhase = phase }
      guard phase != lastPhase else { return }

      switch phase {
         case .acquiringGPS, .idle, .finished:
            liveDetector.reset()
            liveClimb = .idle
            plannedClimbAnchor = nil

         case .recording, .paused:
            break
      }
   }

   /// Re-prepares the progress engine when the route or its profile changes —
   /// a new plan, a reroute, or enrichment landing on the active route.
   private func syncRoute() {
      let route = plannedRouteManager?.activeRoute

      let routeID = route?.id
      let profileCount = route?.elevationProfile.count ?? 0

      guard routeID != preparedRouteID || profileCount != preparedProfileCount else { return }

      preparedRouteID = routeID
      preparedProfileCount = profileCount
      plannedClimbAnchor = nil

      if let route, route.hasElevationProfile {
         progressEngine.prepare(profile: route.elevationProfile, climbs: route.climbs)
      } else {
         progressEngine.reset()
      }
   }

   // MARK: - Route Progress

   private func refreshProgress(with rideState: RideState) {
      guard progressEngine.isReady,
            let guidance = routeGuidanceManager?.progress,
            guidance.isTracking,
            rideState.phase == .recording || rideState.phase == .paused
      else {
         if progress != .none {
            progress = .none
            plannedClimbAnchor = nil
         }
         return
      }

      let refreshed = progressEngine.progress(at: guidance.distanceAlongRoute)
      handleClimbEdges(from: progress, to: refreshed, with: rideState)
      progress = refreshed
   }

   /// Climb starts pulse the pager; climb tops cut a split.
   private func handleClimbEdges(
      from old: ClimbProgress,
      to new: ClimbProgress,
      with rideState: RideState
   ) {
      let oldID = old.activeClimb?.id
      let newID = new.activeClimb?.id
      guard oldID != newID else { return }

      // A climb the rider just topped out. Passing the end distance is what
      // distinguishes cresting from the route being cleared underneath us.
      if let anchor = plannedClimbAnchor,
         anchor.climb.id != newID,
         let playhead = new.playheadDistance,
         playhead >= anchor.climb.endDistance {
         cutPlannedSplit(for: anchor, with: rideState)
      }
      plannedClimbAnchor = nil

      guard let climb = new.activeClimb else { return }

      plannedClimbAnchor = ClimbAnchor(
         climb: climb,
         startedAt: .now,
         startDistance: rideState.distance
      )

      if climb.category != .uncategorized, rideState.phase == .recording {
         climbStartPulse += 1
      }
   }

   private func cutPlannedSplit(for anchor: ClimbAnchor, with rideState: RideState) {
      guard rideState.phase == .recording else { return }

      rideSessionManager?.record(
         climbSplit: RideClimbSplitDraft(
            startDate: anchor.startedAt,
            endDate: .now,
            startDistance: anchor.startDistance,
            endDistance: rideState.distance,
            elevationGain: anchor.climb.ascent,
            averageGrade: anchor.climb.averageGrade,
            category: anchor.climb.category
         )
      )
   }

   // MARK: - Live Detection

   private func feedLiveDetector(with rideState: RideState) {
      guard rideState.phase == .recording, let altitude = rideState.altitude else { return }

      let completed = liveDetector.ingest(
         distance: rideState.distance,
         altitude: altitude,
         timestamp: .now
      )
      liveClimb = liveDetector.status

      // On a profiled route the planned climbs own the splits; cutting from
      // both detectors would record every climb twice.
      guard let completed, !progress.hasRouteProfile else { return }

      rideSessionManager?.record(
         climbSplit: RideClimbSplitDraft(
            startDate: completed.startedAt,
            endDate: completed.endedAt,
            startDistance: completed.startDistance,
            endDistance: completed.endDistance,
            elevationGain: completed.ascent,
            averageGrade: completed.averageGrade,
            category: completed.category
         )
      )
   }
}
