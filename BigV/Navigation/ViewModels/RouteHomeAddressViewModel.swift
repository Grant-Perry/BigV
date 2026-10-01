//
//  RouteHomeAddressViewModel.swift
//  BigV
//

import Foundation

/// Drives the set-home-address sheet: type, pick a result, save.
///
/// Its own view model rather than a mode of the planner's, because it owns a
/// separate `MKLocalSearchCompleter` — the planner's completer may be mid-query
/// on the Ride To tab while this sheet is open from Settings.
@Observable
@MainActor
final class RouteHomeAddressViewModel {

   // MARK: - Query

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
   private(set) var isResolving = false

   // MARK: - Dependencies

   private let routeSearchService: RouteSearchService
   private let currentLocationProbe: CurrentLocationProbe
   private let routeHomeSettings: RouteHomeSettings

   init(
      routeSearchService: RouteSearchService = RouteSearchService(),
      currentLocationProbe: CurrentLocationProbe = CurrentLocationProbe(),
      routeHomeSettings: RouteHomeSettings = RouteHomeSettings()
   ) {
      self.routeSearchService = routeSearchService
      self.currentLocationProbe = currentLocationProbe
      self.routeHomeSettings = routeHomeSettings
   }

   // MARK: - Private State

   private var eventsTask: Task<Void, Never>?
   private var searchTask: Task<Void, Never>?
   private var biasTask: Task<Void, Never>?

   private let keystrokeSettleDelay: Duration = .milliseconds(220)

   // MARK: - Derived State

   var home: RouteDestination? { routeHomeSettings.home }

   var hasHome: Bool { routeHomeSettings.hasHome }

   var homeLabel: String? { routeHomeSettings.homeLabel }

   var statusMessage: String? {
      if let searchFailure { return searchFailure.message }
      guard !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
      return suggestions.isEmpty ? RouteSearchFailure.noResults.message : nil
   }

   // MARK: - Lifecycle

   func begin() {
      guard eventsTask == nil else { return }

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
      biasTask?.cancel()
      biasTask = nil
      eventsTask?.cancel()
      eventsTask = nil

      routeSearchService.stopUpdates()
      queryText = ""
      suggestions = []
      searchFailure = nil
      isResolving = false
   }

   // MARK: - Intent

   /// Resolves the pick and saves it as home. Returns `false` when the result
   /// could not be turned into a place, in which case the sheet stays up.
   @discardableResult
   func choose(_ suggestion: RouteSearchSuggestion) async -> Bool {
      guard !isResolving else { return false }

      isResolving = true
      defer { isResolving = false }

      do {
         let destination = try await routeSearchService.resolve(suggestion)
         routeHomeSettings.home = destination
         DebugPrint(mode: .navigation, "Home set to \(destination.name)")
         return true
      } catch {
         searchFailure = error
         return false
      }
   }

   func clearHome() {
      routeHomeSettings.clearHome()
   }

   // MARK: - Search

   private func scheduleSearch() {
      searchTask?.cancel()

      guard !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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
}
