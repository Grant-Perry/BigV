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

   /// Whether Open-Meteo elevation is still in flight for the candidates. The
   /// preview shows "Loading elevation…" from this rather than from each row,
   /// because every candidate is enriched by the same pass.
   private(set) var isEnrichingElevation = false

   /// Set when a chosen GPX file could not become a route, cleared by the next
   /// import or search.
   private(set) var gpxImportFailureMessage: String?

   // MARK: - Dependencies

   private let routeSearchService: RouteSearchService
   private let plannedRouteProvider: any PlannedRouteProviding
   private let currentLocationProbe: CurrentLocationProbe
   private let plannedRouteManager: PlannedRouteManager
   private let routeElevationEnricher: RouteElevationEnricher

   init(
      routeSearchService: RouteSearchService = RouteSearchService(),
      plannedRouteProvider: any PlannedRouteProviding = MapKitCyclingRoutePlanner(),
      currentLocationProbe: CurrentLocationProbe = CurrentLocationProbe(),
      plannedRouteManager: PlannedRouteManager = PlannedRouteManager(),
      routeElevationEnricher: RouteElevationEnricher = RouteElevationEnricher()
   ) {
      self.routeSearchService = routeSearchService
      self.plannedRouteProvider = plannedRouteProvider
      self.currentLocationProbe = currentLocationProbe
      self.plannedRouteManager = plannedRouteManager
      self.routeElevationEnricher = routeElevationEnricher
   }

   // MARK: - Private State

   /// Retires a resolution or a routing request the rider has moved on from.
   private var generation = RouteRequestGeneration()

   private var eventsTask: Task<Void, Never>?
   private var searchTask: Task<Void, Never>?
   private var planTask: Task<Void, Never>?
   private var biasTask: Task<Void, Never>?
   private var enrichTask: Task<Void, Never>?

   /// Enrichment for a route the rider already committed to. Deliberately not
   /// cancelled by `end()`: confirming a route leaves the planner tab, and the
   /// profile should still land on the active route moments later.
   private var activationEnrichTask: Task<Void, Never>?

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

      enrichTask?.cancel()
      enrichTask = nil

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
      enrichActiveRouteIfNeeded(route)
      discardPlanning()
      queryText = ""
      suggestions = []
      routeSearchService.cancel()
   }

   func cancelPreview() {
      discardPlanning()
   }

   // MARK: - GPX Import

   /// Turns a picked GPX file into a single-candidate preview.
   ///
   /// Same stage flow as a search: the imported route lands in `candidates`,
   /// the stage flips to preview, and Follow Route works unchanged. The
   /// destination pin is the track's own endpoint.
   func importGPXRoute(from url: URL) {
      searchTask?.cancel()
      routeSearchService.cancel()
      discardPlanning()
      suggestions = []
      searchFailure = nil
      gpxImportFailureMessage = nil

      let ticket = generation.issue()
      isPlanning = true

      planTask = Task { [weak self] in
         await self?.importGPX(url, ticket: ticket)
      }
   }

   private func importGPX(_ url: URL, ticket: UInt64) async {
      let route: PlannedRoute?

      // Parsed off the main actor: a season of track points is real work, and
      // the planning spinner is already on screen.
      do {
         route = try await Task.detached(priority: .userInitiated) {
            try GPXRouteImporter.route(from: Self.readImportedFile(url))
         }.value
      } catch {
         route = nil
         DebugPrint(mode: .navigation, "GPX import failed: \(error)")
      }

      guard generation.isCurrent(ticket) else { return }

      guard let route, let endCoordinate = route.endCoordinate else {
         isPlanning = false
         gpxImportFailureMessage = "That file doesn't contain a rideable track."
         return
      }

      destination = RouteDestination(
         name: route.name.isEmpty ? "GPX Route" : route.name,
         coordinate: endCoordinate
      )
      candidates = [route]
      selectedCandidateID = route.id
      previewRegion = RideRouteBounds.region(for: route.coordinates)
      isPlanning = false

      // A track with no <ele> is enriched like any Apple route.
      enrichCandidates(ticket: ticket)
   }

   /// Reads a document-picker URL under its security scope.
   private nonisolated static func readImportedFile(_ url: URL) throws -> Data {
      let isScoped = url.startAccessingSecurityScopedResource()
      defer {
         if isScoped { url.stopAccessingSecurityScopedResource() }
      }
      return try Data(contentsOf: url)
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
         enrichCandidates(ticket: ticket)
      } catch {
         apply(planningFailure: error, ticket: ticket)
      }
   }

   // MARK: - Elevation

   /// Attaches Open-Meteo profiles to every candidate at once.
   ///
   /// Candidates are replaced in place by id as each profile lands, so the row
   /// the rider is reading grows its gain figure without the list reordering.
   /// Fail-soft throughout: a candidate that cannot be enriched previews and
   /// rides exactly as before, minus the climb figures.
   private func enrichCandidates(ticket: UInt64) {
      enrichTask?.cancel()

      let routes = candidates.filter { !$0.hasElevationProfile }
      guard !routes.isEmpty else { return }

      isEnrichingElevation = true
      let enricher = routeElevationEnricher

      enrichTask = Task { [weak self] in
         await withTaskGroup(of: PlannedRoute.self) { group in
            for route in routes {
               group.addTask { await enricher.enriched(route) }
            }

            for await enriched in group {
               guard !Task.isCancelled else { return }
               self?.replaceCandidate(with: enriched, ticket: ticket)
            }
         }

         guard let self, self.generation.isCurrent(ticket) else { return }
         self.isEnrichingElevation = false
      }
   }

   private func replaceCandidate(with enriched: PlannedRoute, ticket: UInt64) {
      guard generation.isCurrent(ticket),
            let index = candidates.firstIndex(where: { $0.id == enriched.id })
      else { return }

      candidates[index] = enriched
   }

   /// Backfills the profile onto a route confirmed before enrichment landed.
   private func enrichActiveRouteIfNeeded(_ route: PlannedRoute) {
      guard !route.hasElevationProfile else { return }

      let enricher = routeElevationEnricher
      let manager = plannedRouteManager

      activationEnrichTask?.cancel()
      activationEnrichTask = Task {
         let enriched = await enricher.enriched(route)
         guard !Task.isCancelled else { return }
         manager.attachElevation(from: enriched)
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
      enrichTask?.cancel()
      enrichTask = nil
      plannedRouteProvider.cancel()

      candidates = []
      selectedCandidateID = nil
      previewRegion = nil
      destination = nil
      planningFailure = nil
      isPlanning = false
      isEnrichingElevation = false
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

   /// "+853 FT · 2 climbs", once elevation has landed. `nil` says nothing is
   /// known yet — the row shows the loading whisper off `isEnrichingElevation`.
   func climbSummaryText(for route: PlannedRoute) -> String? {
      guard route.hasElevationProfile, let ascent = route.totalAscent else { return nil }
      return PlannedRouteFormatters.climbSummary(ascent: ascent, climbCount: route.climbs.count)
   }
}

// MARK: - Trimming

private extension String {

   var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
