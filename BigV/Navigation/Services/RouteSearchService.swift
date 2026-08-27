//
//  RouteSearchService.swift
//  BigV
//

import CoreLocation
import Foundation
import MapKit

/// As-you-type destination search, and the resolution of a chosen result into a
/// coordinate worth routing to.
///
/// `MKLocalSearchCompleter` is delegate-based and its callbacks carry no clue
/// which query fragment they answer, so every request takes a ticket from
/// `RouteRequestGeneration` and only the newest ticket is allowed to publish.
/// The completer is wrapped in an `AsyncStream`, the same shape
/// `RideLocationManager` uses for Core Location.
///
/// The only type in the app that knows `MKLocalSearchCompleter` exists.
@MainActor
final class RouteSearchService: NSObject, MKLocalSearchCompleterDelegate {

   // MARK: - Events

   enum Event: Sendable {
      case suggestions([RouteSearchSuggestion])
      case failure(RouteSearchFailure)
   }

   // MARK: - Tuning

   /// How far around the rider results are pulled toward. Wide enough that the
   /// next town over is still reachable, tight enough that "Main Street" means
   /// the one they can ride to.
   private static let biasRadius: CLLocationDistance = 40_000

   // MARK: - Private State

   private let completer = MKLocalSearchCompleter()

   private var continuation: AsyncStream<Event>.Continuation?

   /// Retains the MapKit handle behind each published suggestion.
   ///
   /// Kept for the whole search session rather than cleared per batch: a row the
   /// rider taps in the instant before SwiftUI redraws a newer batch is still a
   /// row they meant to tap, and losing its handle would fail the tap for no
   /// reason the rider could understand.
   private var completions: [Int: MKLocalSearchCompletion] = [:]

   private var nextSuggestionID = 0

   /// Guards the completer only. Its delegate callbacks are the one answer the
   /// caller cannot ticket for itself, because they arrive unbidden and name no
   /// query. Resolution is awaited, so its ordering is the caller's to enforce.
   private var generation = RouteRequestGeneration()
   private var completionTicket: UInt64 = 0

   private var search: MKLocalSearch?

   // MARK: - Initialization

   override init() {
      super.init()

      completer.resultTypes = [.address, .pointOfInterest]
      completer.delegate = self
   }

   // MARK: - Stream

   /// Starts event delivery. Any previous stream is torn down first.
   func startUpdates() -> AsyncStream<Event> {
      continuation?.finish()

      let (stream, continuation) = AsyncStream<Event>.makeStream(
         bufferingPolicy: .bufferingNewest(4)
      )
      self.continuation = continuation

      return stream
   }

   func stopUpdates() {
      cancel()

      continuation?.finish()
      continuation = nil
   }

   // MARK: - Biasing

   /// Pulls results toward the rider. Unset while their position is unknown, in
   /// which case Apple falls back to its own guess rather than nothing.
   func biasResults(toward coordinate: CLLocationCoordinate2D?) {
      guard let coordinate, RideRouteDownsampler.isUsable(coordinate) else { return }

      completer.region = MKCoordinateRegion(
         center: coordinate,
         latitudinalMeters: Self.biasRadius,
         longitudinalMeters: Self.biasRadius
      )
   }

   // MARK: - Searching

   func search(for query: String) {
      let fragment = query.trimmingCharacters(in: .whitespacesAndNewlines)

      guard !fragment.isEmpty else {
         cancel()
         continuation?.yield(.suggestions([]))
         return
      }

      completionTicket = generation.issue()
      completer.queryFragment = fragment
   }

   /// Abandons in-flight work. Late answers are already retired by the ticket,
   /// so nothing can arrive afterwards and repopulate a cleared list.
   func cancel() {
      generation.retireAll()
      completer.cancel()
      search?.cancel()
      search = nil
      completions.removeAll(keepingCapacity: true)
   }

   // MARK: - Resolution

   /// Turns a chosen suggestion into somewhere to ride to.
   ///
   /// A second search started while this one is in flight cancels it, so the
   /// abandoned request fails rather than answering late.
   func resolve(
      _ suggestion: RouteSearchSuggestion
   ) async throws(RouteSearchFailure) -> RouteDestination {
      guard let completion = completions[suggestion.id] else { throw .failed }

      let search = MKLocalSearch(request: MKLocalSearch.Request(completion: completion))
      self.search?.cancel()
      self.search = search

      let response: MKLocalSearch.Response

      do {
         response = try await search.start()
      } catch {
         throw Self.failure(for: error)
      }

      guard let destination = Self.destination(from: response, fallbackName: suggestion.title) else {
         throw .noResults
      }

      DebugPrint(mode: .navigation, "Resolved destination \(destination.name)")

      return destination
   }

   // MARK: - Completer Delegate

   func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
      guard generation.isCurrent(completionTicket) else {
         DebugPrint(mode: .navigation, "Discarded stale completion batch")
         return
      }

      let suggestions = completer.results.map { completion -> RouteSearchSuggestion in
         nextSuggestionID += 1
         completions[nextSuggestionID] = completion

         return RouteSearchSuggestion(
            id: nextSuggestionID,
            title: completion.title,
            subtitle: completion.subtitle
         )
      }

      continuation?.yield(.suggestions(suggestions))
   }

   func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
      guard generation.isCurrent(completionTicket) else { return }

      let failure = Self.failure(for: error)
      DebugPrint(mode: .navigation, "Completion failed: \(failure.rawValue) — \(error)")

      continuation?.yield(.failure(failure))
   }

   // MARK: - Mapping

   private static func destination(
      from response: MKLocalSearch.Response,
      fallbackName: String
   ) -> RouteDestination? {
      guard let item = response.mapItems.first else { return nil }

      let coordinate = item.location.coordinate
      guard RideRouteDownsampler.isUsable(coordinate) else { return nil }

      return RouteDestination(
         name: item.name ?? fallbackName,
         detail: item.address?.shortAddress ?? item.address?.fullAddress,
         coordinate: coordinate
      )
   }

   private static func failure(for error: any Error) -> RouteSearchFailure {
      if RouteErrorClassifier.isOffline(error) { return .offline }

      guard let mapKitError = error as? MKError else { return .failed }

      return mapKitError.code == .placemarkNotFound ? .noResults : .failed
   }
}
