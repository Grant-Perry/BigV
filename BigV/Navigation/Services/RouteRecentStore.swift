//
//  RouteRecentStore.swift
//  BigV
//

import Foundation
import Observation

/// Remembers the last few places the rider navigated to.
///
/// Same tier as favorites — JSON in UserDefaults — and the same shape, so the
/// planner reads both the same way. Newest first, capped, deduplicated by
/// place: riding home every evening is one row, not eight.
@Observable
@MainActor
final class RouteRecentStore {

   // MARK: - Tuning

   /// Enough to cover a week of varied riding, few enough to scan with a
   /// gloved thumb.
   static let limit = 8

   // MARK: - Published State

   private(set) var recents: [RouteRecentDestination] = []

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

   var isEmpty: Bool { recents.isEmpty }

   /// Moves the place to the top, or adds it there, trimming the oldest past
   /// the cap.
   func record(_ destination: RouteDestination) {
      let entry = RouteRecentDestination(destination: destination)

      recents.removeAll { $0.key == entry.key }
      recents.insert(entry, at: 0)

      if recents.count > Self.limit {
         recents.removeLast(recents.count - Self.limit)
      }

      persist()
   }

   func remove(id: RouteRecentDestination.ID) {
      guard recents.contains(where: { $0.id == id }) else { return }
      recents.removeAll { $0.id == id }
      persist()
   }

   func clear() {
      guard !recents.isEmpty else { return }
      recents = []
      persist()
   }

   // MARK: - Persistence

   private enum Key {
      static let recents = "route.recents.v1"
   }

   private func load() {
      guard let data = defaults.data(forKey: Key.recents) else {
         recents = []
         return
      }

      do {
         recents = try decoder.decode([RouteRecentDestination].self, from: data)
      } catch {
         DebugPrint(mode: .persistence, "Route recents decode failed: \(error)")
         recents = []
      }
   }

   private func persist() {
      do {
         let data = try encoder.encode(recents)
         defaults.set(data, forKey: Key.recents)
      } catch {
         DebugPrint(mode: .persistence, "Route recents encode failed: \(error)")
      }
   }
}
