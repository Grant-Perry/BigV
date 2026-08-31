//
//  RideBackToStartModel.swift
//  BigV
//

import CoreLocation
import Foundation
import Observation

/// Gets the rider home: Garmin's two Back to Start modes behind one sheet.
///
/// Along the same route reverses the recorded breadcrumb — no network, works
/// anywhere the rider has already been. Most direct asks MapKit for a fresh
/// cycling route from here to the first accepted fix, and can fail where
/// coverage is thin, which is why retrace is listed first.
///
/// Deliberately its own intent, not a reuse of the wrong-way reroute path:
/// reroute serves the route the rider is on; this replaces it with a new one.
@Observable
@MainActor
final class RideBackToStartModel {

   // MARK: - Published State

   /// Whether the confirmation sheet is on screen. The status row raises it;
   /// the sheet and its actions lower it.
   var isPresentingOptions = false

   private(set) var isPlanning = false

   /// Why most-direct could not produce a route, for the sheet to show.
   private(set) var failureMessage: String?

   // MARK: - Dependencies

   /// Optional so previews can build the sheet with no ride behind it.
   @ObservationIgnored private let rideRouteRecorder: RideRouteRecorder?
   @ObservationIgnored private let plannedRouteManager: PlannedRouteManager?
   @ObservationIgnored private let plannedRouteProvider: (any PlannedRouteProviding)?
   @ObservationIgnored private let routeElevationEnricher: RouteElevationEnricher

   @ObservationIgnored private var planTask: Task<Void, Never>?
   @ObservationIgnored private var enrichTask: Task<Void, Never>?

   // MARK: - Initialization

   init(
      rideRouteRecorder: RideRouteRecorder? = nil,
      plannedRouteManager: PlannedRouteManager? = nil,
      plannedRouteProvider: (any PlannedRouteProviding)? = nil,
      routeElevationEnricher: RouteElevationEnricher = RouteElevationEnricher()
   ) {
      self.rideRouteRecorder = rideRouteRecorder
      self.plannedRouteManager = plannedRouteManager
      self.plannedRouteProvider = plannedRouteProvider
      self.routeElevationEnricher = routeElevationEnricher
   }

   // MARK: - Availability

   /// There is a start to go back to once the breadcrumb has a first fix and
   /// enough track that "back" means something.
   var isAvailable: Bool {
      rideRouteRecorder?.hasRoute ?? false
   }

   /// The ride's first accepted fix — where both modes lead.
   private var startCoordinate: CLLocationCoordinate2D? {
      rideRouteRecorder?.coordinates.first
   }

   // MARK: - Intent

   func presentOptions() {
      failureMessage = nil
      isPresentingOptions = true
   }

   func dismissOptions() {
      planTask?.cancel()
      planTask = nil
      isPlanning = false
      isPresentingOptions = false
   }

   /// Reverses the breadcrumb into the route home and follows it.
   func retraceRoute() {
      guard let breadcrumb = rideRouteRecorder?.coordinates,
            let start = startCoordinate,
            let route = RideRetraceRouteBuilder.route(reversing: breadcrumb)
      else {
         failureMessage = "Not enough ride recorded to retrace."
         return
      }

      activate(route, start: start)
      isPresentingOptions = false
   }

   /// Asks MapKit for the straightest cycling line home and follows the best
   /// candidate.
   func planMostDirect() {
      guard let plannedRouteProvider,
            let start = startCoordinate,
            let current = rideRouteRecorder?.coordinates.last
      else {
         failureMessage = "No ride start on record yet."
         return
      }

      failureMessage = nil
      isPlanning = true
      planTask?.cancel()

      planTask = Task { [weak self] in
         defer { self?.isPlanning = false }

         do {
            let destination = RouteDestination(name: "Ride Start", coordinate: start)
            let routes = try await plannedRouteProvider.routes(from: current, to: destination)

            guard !Task.isCancelled, let self, let best = routes.first else { return }

            self.activate(best, start: start)
            self.isPresentingOptions = false
         } catch {
            guard !Task.isCancelled else { return }
            self?.failureMessage = (error as? RoutePlanningFailure)?.message
               ?? RoutePlanningFailure.failed.message
         }
      }
   }

   // MARK: - Activation

   /// Hands the route to the same manager the planner uses, so guidance, the
   /// map line, To Go and ETA all take over without knowing who planned it.
   private func activate(_ route: PlannedRoute, start: CLLocationCoordinate2D) {
      plannedRouteManager?.activate(
         route,
         to: RouteDestination(name: "Ride Start", coordinate: start)
      )

      enrichElevation(for: route)

      DebugPrint(
         mode: .navigation,
         "Back to Start following \(route.source.rawValue) route, \(Int(route.distance)) m"
      )
   }

   /// The way home deserves the same climb picture as any planned route. Fail
   /// soft, like every other enrichment.
   private func enrichElevation(for route: PlannedRoute) {
      guard !route.hasElevationProfile else { return }

      enrichTask?.cancel()
      let enricher = routeElevationEnricher

      enrichTask = Task { [weak self] in
         let enriched = await enricher.enriched(route)
         guard !Task.isCancelled, enriched.hasElevationProfile else { return }
         self?.plannedRouteManager?.attachElevation(from: enriched)
      }
   }
}
