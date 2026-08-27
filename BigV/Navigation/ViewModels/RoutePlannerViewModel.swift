//
//  RoutePlannerViewModel.swift
//  BigV
//

import CoreLocation
import Foundation
import MapKit

/// Drives the whole plan-a-route flow: type a destination, pick one, look at the
/// candidates, commit or walk away.
///
/// One view model rather than three because the stages share one piece of state —
/// the chosen destination — and splitting them would mean either a view model
/// calling another or a view wiring them together in its body. Search and routing
/// are separate services underneath; only their coordination lives here.
@Observable
@MainActor
final class RoutePlannerViewModel {

   // MARK: - Stage

   enum Stage: Sendable {
      case search
      case planning
      case preview
   }

   // MARK: - Query

   /// Writing this schedules a search. Backed by a tracked stored property so
   /// SwiftUI can still bind to it directly.
   var query: String {
      get { queryText }
      set {
         guard newValue != queryText else { return }
         queryText = newValue
         scheduleSearch()
      }
   }

   private var queryText = ""

   // MARK: - Published State

   private(set) var suggestions: [RouteSearchSuggestion] = []
   private(set) var searchFailure: RouteSearchFailure?

   private(set) var candidates: [PlannedRoute] = []
   private(set) var selectedCandidateID: PlannedRoute.ID?
   private(set) var planningFailure: RoutePlanningFailure?
   private(set) var destination: RouteDestination?

   /// Frames every candidate at once, so choosing an alternate never moves the
   /// camera out from under the rider's finger.
   private(set) var previewRegion: MKCoordinateRegion?

   private(set) var isPlanning = false

   // MARK: - Dependencies

   private let routeSearchService: RouteSearchService
   private let plannedRouteProvider: any PlannedRouteProviding
   private let currentLocationProbe: CurrentLocationProbe
   private let plannedRouteManager: PlannedRouteManager

   init(
      routeSearchService: RouteSearchService = RouteSearchService(),
      plannedRouteProvider: any PlannedRouteProviding = MapKitCyclingRoutePlanner(),
      currentLocationProbe: CurrentLocationProbe = CurrentLocationProbe(),
      plannedRouteManager: PlannedRouteManager = PlannedRouteManager()
   ) {
      self.routeSearchService = routeSearchService
      self.plannedRouteProvider = plannedRouteProvider
      self.currentLocationProbe = currentLocationProbe
      self.plannedRouteManager = plannedRouteManager
   }

   // MARK: - Private State

   /// Retires a resolution or a routing request the rider has moved on from.
   private var generation = RouteRequestGeneration()

   private var eventsTask: Task<Void, Never>?
   private var searchTask: Task<Void, Never>?
   private var planTask: Task<Void, Never>?
   private var biasTask: Task<Void, Never>?

   /// Long enough that a rider typing a street name does not fire a request per
   /// character, short enough to still feel like it is keeping up.
   private let keystrokeSettleDelay: Duration = .milliseconds(220)

   // MARK: - Derived State

   var stage: Stage {
      if !candidates.isEmpty { return .preview }
      if isPlanning { return .planning }
      return .search
   }

   var selectedCandidate: PlannedRoute? {
      candidates.first { $0.id == selectedCandidateID } ?? candidates.first
   }

   var hasActiveRoute: Bool { plannedRouteManager.hasActiveRoute }

   var activeDestinationName: String? { plannedRouteManager.destination?.name }

   var destinationName: String { destination?.name ?? "Route" }

   /// What to say when the results list has nothing in it. `nil` means the list
   /// is doing its job and needs no explanation.
   var searchStatusMessage: String? {
      if let searchFailure { return searchFailure.message }
      guard !queryText.trimmed.isEmpty else { return nil }
      return suggestions.isEmpty ? RouteSearchFailure.noResults.message : nil
   }

   var canConfirm: Bool { selectedCandidate?.isDrawable ?? false }

   // MARK: - Lifecycle

   func begin() {
      guard eventsTask == nil else { return }

      currentLocationProbe.requestAuthorizationIfNeeded()

      let stream = routeSearchService.startUpdates()
      eventsTask = Task { [weak self] in
         for await event in stream {
            self?.handle(event)
         }
      }

      biasTask = Task { [weak self] in
         guard let coordinate = await self?.currentLocationProbe.coordinate() else { return }
         self?.routeSearchService.biasResults(toward: coordinate)
      }
   }

   func end() {
      searchTask?.cancel()
      searchTask = nil

      planTask?.cancel()
      planTask = nil

      biasTask?.cancel()
      biasTask = nil

      eventsTask?.cancel()
      eventsTask = nil

      generation.retireAll()
      routeSearchService.stopUpdates()
      plannedRouteProvider.cancel()
   }

   // MARK: - Search Intent

   private func scheduleSearch() {
      searchTask?.cancel()
      discardPlanning()

      guard !queryText.trimmed.isEmpty else {
         routeSearchService.cancel()
         suggestions = []
         searchFailure = nil
         return
      }

      let fragment = queryText
      let settleDelay = keystrokeSettleDelay

      searchTask = Task { [weak self] in
         try? await Task.sleep(for: settleDelay)
         guard !Task.isCancelled else { return }
         self?.routeSearchService.search(for: fragment)
      }
   }

   private func handle(_ event: RouteSearchService.Event) {
      switch event {
         case .suggestions(let suggestions):
            self.suggestions = suggestions
            searchFailure = nil

         case .failure(let failure):
            suggestions = []
            searchFailure = failure
      }
   }

   // MARK: - Planning Intent

   func select(_ suggestion: RouteSearchSuggestion) {
      planTask?.cancel()

      let ticket = generation.issue()
      searchFailure = nil
      planningFailure = nil
      candidates = []
      previewRegion = nil
      isPlanning = true

      planTask = Task { [weak self] in
         await self?.plan(suggestion, ticket: ticket)
      }
   }

   func selectCandidate(_ id: PlannedRoute.ID) {
      guard candidates.contains(where: { $0.id == id }) else { return }
      selectedCandidateID = id
   }

   func confirm() {
      guard let route = selectedCandidate, let destination else { return }

      plannedRouteManager.activate(route, to: destination)
      discardPlanning()
      queryText = ""
      suggestions = []
      routeSearchService.cancel()
   }

   func cancelPreview() {
      discardPlanning()
   }

   func clearActiveRoute() {
      plannedRouteManager.clear()
   }

   // MARK: - Planning

   private func plan(_ suggestion: RouteSearchSuggestion, ticket: UInt64) async {
      let resolved: RouteDestination

      do {
         resolved = try await routeSearchService.resolve(suggestion)
      } catch {
         apply(searchFailure: error, ticket: ticket)
         return
      }

      guard generation.isCurrent(ticket) else { return }
      destination = resolved

      guard let origin = await currentLocationProbe.coordinate() else {
         apply(planningFailure: .originUnavailable, ticket: ticket)
         return
      }

      guard generation.isCurrent(ticket) else { return }

      do {
         let routes = try await plannedRouteProvider.routes(from: origin, to: resolved)
         guard generation.isCurrent(ticket) else { return }

         candidates = routes
         selectedCandidateID = routes.first?.id
         previewRegion = RideRouteBounds.region(for: routes.flatMap(\.coordinates))
         isPlanning = false
      } catch {
         apply(planningFailure: error, ticket: ticket)
      }
   }

   // MARK: - Failure Handling

   private func apply(searchFailure failure: RouteSearchFailure, ticket: UInt64) {
      guard generation.isCurrent(ticket) else { return }

      isPlanning = false
      searchFailure = failure
   }

   private func apply(planningFailure failure: RoutePlanningFailure, ticket: UInt64) {
      guard generation.isCurrent(ticket) else { return }

      isPlanning = false
      planningFailure = failure
   }

   // MARK: - Reset

   private func discardPlanning() {
      generation.retireAll()
      planTask?.cancel()
      planTask = nil
      plannedRouteProvider.cancel()

      candidates = []
      selectedCandidateID = nil
      previewRegion = nil
      destination = nil
      planningFailure = nil
      isPlanning = false
   }
}

// MARK: - Presentation

extension RoutePlannerViewModel {

   func distanceText(for route: PlannedRoute) -> String {
      PlannedRouteFormatters.distance(route.distance)
   }

   func travelTimeText(for route: PlannedRoute) -> String {
      PlannedRouteFormatters.travelTime(route.expectedTravelTime)
   }

   /// Apple ranks its own routes, so the first is the one it recommends. The
   /// provider's own label goes underneath when it has one.
   func title(forCandidateAt index: Int) -> String {
      index == 0 ? "Recommended" : "Alternate \(index)"
   }

   func detail(for route: PlannedRoute) -> String? {
      route.name.isEmpty ? nil : "via \(route.name)"
   }

   func isSelected(_ route: PlannedRoute) -> Bool {
      route.id == selectedCandidate?.id
   }
}

// MARK: - Trimming

private extension String {

   var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
