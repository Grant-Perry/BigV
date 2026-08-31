//
//  RouteFavoriteStore.swift
//  BigV
//

import Foundation
import Observation

/// Remembers routes the rider starred in the planner.
///
/// JSON in UserDefaults — the same tier as units and climb prefs. A favorite
/// carries full geometry so a saved GPX or Apple route replays without another
/// fetch.
@Observable
@MainActor
final class RouteFavoriteStore {

   // MARK: - Published State

   private(set) var favorites: [SavedRouteFavorite] = []

   // MARK: - Dependencies

   @ObservationIgnored private let defaults: UserDefaults
   @ObservationIgnored private let encoder: JSONEncoder = {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      return encoder
   }()

   @ObservationIgnored private let decoder: JSONDecoder = {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      return decoder
   }()

   // MARK: - Initialization

   init(defaults: UserDefaults = .standard) {
      self.defaults = defaults
      load()
   }

   // MARK: - Access

   var isEmpty: Bool { favorites.isEmpty }

   func isFavorite(route: PlannedRoute, destination: RouteDestination) -> Bool {
      favorites.contains { $0.matches(route: route, destination: destination) }
   }

   /// Adds or removes the route. Returns the new favorite state.
   @discardableResult
   func toggle(route: PlannedRoute, destination: RouteDestination) -> Bool {
      if let index = favorites.firstIndex(where: { $0.matches(route: route, destination: destination) }) {
         favorites.remove(at: index)
         persist()
         return false
      }

      favorites.insert(SavedRouteFavorite(route: route, destination: destination), at: 0)
      persist()
      return true
   }

   func remove(id: SavedRouteFavorite.ID) {
      guard favorites.contains(where: { $0.id == id }) else { return }
      favorites.removeAll { $0.id == id }
      persist()
   }

   // MARK: - Persistence

   private enum Key {
      static let favorites = "route.favorites.v1"
   }

   private func load() {
      guard let data = defaults.data(forKey: Key.favorites) else {
         favorites = []
         return
      }

      do {
         favorites = try decoder.decode([SavedRouteFavorite].self, from: data)
      } catch {
         DebugPrint(mode: .persistence, "Route favorites decode failed: \(error)")
         favorites = []
      }
   }

   private func persist() {
      do {
         let data = try encoder.encode(favorites)
         defaults.set(data, forKey: Key.favorites)
      } catch {
         DebugPrint(mode: .persistence, "Route favorites encode failed: \(error)")
      }
   }
}
