//
//  RideCockpitLayoutSettings.swift
//  BigV
//

import Foundation

// MARK: - Surface

/// A screen whose cards the rider can rearrange. Each keeps its own slots,
/// and the no-duplicates rule is judged within one surface: distance on the
/// dashboard and distance on the Traffic page are two screens, not two cards.
enum RideCockpitSurface: String, Sendable, Codable {
   case dashboard
   case traffic
}

// MARK: - Swap Request

/// A card the rider is holding down, waiting to be told what goes there.
struct RideCockpitMetricSwapRequest: Equatable, Sendable {
   let metric: RideCockpitMetric
   let surface: RideCockpitSurface
}

// MARK: - Choices

/// What the picker offers for one held card.
///
/// Swaps are cards already on the screen: pick one and the two trade places,
/// so nothing is lost. Replacements are metrics not on the screen at all:
/// pick one and it takes the held card's slot. A protected card offers no
/// replacements — that is the whole guard.
struct RideCockpitMetricChoices: Equatable, Sendable {
   var swaps: [RideCockpitMetric]
   var replacements: [RideCockpitMetric]

   var isEmpty: Bool { swaps.isEmpty && replacements.isEmpty }
}

// MARK: - Settings

/// Which metric sits in which cockpit slot, observable and persisted.
///
/// A slot list per surface, in reading order. The dashboard renders its first
/// two slots as the big pair under the hero and the rest in the grid; the
/// Traffic page renders its two slots down the instrument column. A slot whose
/// metric has no data right now (no Watch, no route) simply does not draw, the
/// same way those tiles always came and went.
///
/// UserDefaults cannot notify `@Observable` tracking, so each list is a stored
/// mirror loaded once and written through on set, like every other settings
/// object in the app.
@Observable
@MainActor
final class RideCockpitLayoutSettings {

   // MARK: - Keys

   private enum Key {
      static let dashboard = "cockpit.tiles.dashboard"
      static let traffic = "cockpit.tiles.traffic"
   }

   // MARK: - Defaults

   /// The dashboard as it was before cards could move: the two totals, then
   /// climb, grade, altitude, pulse, VAM, moving time, and what a route adds.
   static let defaultDashboardTiles: [RideCockpitMetric] = [
      .distance,
      .rideTime,
      .elevationGain,
      .grade,
      .altitude,
      .heartRate,
      .verticalSpeed,
      .movingTime,
      .ascentRemaining,
      .distanceToGo,
      .arrivalTime
   ]

   /// Beside the road: how far and how long.
   static let defaultTrafficTiles: [RideCockpitMetric] = [.distance, .rideTime]

   @ObservationIgnored private let defaults: UserDefaults

   // MARK: - Slots

   private(set) var dashboardTiles: [RideCockpitMetric] {
      didSet { defaults.set(dashboardTiles.map(\.rawValue), forKey: Key.dashboard) }
   }

   private(set) var trafficTiles: [RideCockpitMetric] {
      didSet { defaults.set(trafficTiles.map(\.rawValue), forKey: Key.traffic) }
   }

   func tiles(on surface: RideCockpitSurface) -> [RideCockpitMetric] {
      switch surface {
         case .dashboard: dashboardTiles
         case .traffic: trafficTiles
      }
   }

   // MARK: - Initialization

   init(defaults: UserDefaults = .standard) {
      self.defaults = defaults

      dashboardTiles = Self.load(
         defaults.stringArray(forKey: Key.dashboard),
         fallback: Self.defaultDashboardTiles
      )
      trafficTiles = Self.load(
         defaults.stringArray(forKey: Key.traffic),
         fallback: Self.defaultTrafficTiles
      )
   }

   /// A stored list is trusted only as far as it can be: unknown names are
   /// dropped, duplicates collapse to their first appearance, and a protected
   /// metric that somehow went missing comes back at the front.
   private static func load(_ stored: [String]?, fallback: [RideCockpitMetric]) -> [RideCockpitMetric] {
      guard let stored else { return fallback }
      return sanitize(stored.compactMap(RideCockpitMetric.init(rawValue:)), fallback: fallback)
   }

   static func sanitize(_ tiles: [RideCockpitMetric], fallback: [RideCockpitMetric]) -> [RideCockpitMetric] {
      var seen = Set<RideCockpitMetric>()
      var result = tiles.filter { seen.insert($0).inserted }

      for metric in fallback where metric.isProtected && !result.contains(metric) {
         result.insert(metric, at: 0)
      }
      return result.isEmpty ? fallback : result
   }

   // MARK: - Choices

   /// What a held card may become, given which metrics have data right now.
   func choices(
      for metric: RideCockpitMetric,
      on surface: RideCockpitSurface,
      available: Set<RideCockpitMetric>
   ) -> RideCockpitMetricChoices {
      let tiles = tiles(on: surface)

      let swaps = tiles.filter { $0 != metric && available.contains($0) }

      let replacements = metric.isProtected
         ? []
         : RideCockpitMetric.allCases.filter { available.contains($0) && !tiles.contains($0) }

      return RideCockpitMetricChoices(swaps: swaps, replacements: replacements)
   }

   // MARK: - Mutation

   /// Puts `target` where `metric` is. A target already on the surface trades
   /// places with it; one that is not takes its slot. Returns whether anything
   /// changed — a protected card refuses to be replaced, and a target that is
   /// on the surface but has no data is refused too, because a swap with a
   /// card the rider cannot see is a card that vanishes.
   @discardableResult
   func apply(
      _ target: RideCockpitMetric,
      for metric: RideCockpitMetric,
      on surface: RideCockpitSurface,
      available: Set<RideCockpitMetric>
   ) -> Bool {
      let choices = choices(for: metric, on: surface, available: available)

      if choices.swaps.contains(target) {
         return swap(metric, with: target, on: surface)
      }
      if choices.replacements.contains(target) {
         return replace(metric, with: target, on: surface)
      }
      return false
   }

   /// Two cards on the same surface trade slots.
   @discardableResult
   func swap(_ metric: RideCockpitMetric, with other: RideCockpitMetric, on surface: RideCockpitSurface) -> Bool {
      var tiles = tiles(on: surface)
      guard metric != other,
            let first = tiles.firstIndex(of: metric),
            let second = tiles.firstIndex(of: other)
      else { return false }

      tiles.swapAt(first, second)
      store(tiles, on: surface)
      return true
   }

   /// A metric not on the surface takes the held card's slot. Refused for a
   /// protected card, and for a replacement that is already on the surface —
   /// that would be a duplicate, and duplicates are what swap is for.
   @discardableResult
   func replace(_ metric: RideCockpitMetric, with other: RideCockpitMetric, on surface: RideCockpitSurface) -> Bool {
      var tiles = tiles(on: surface)
      guard !metric.isProtected,
            !tiles.contains(other),
            let index = tiles.firstIndex(of: metric)
      else { return false }

      tiles[index] = other
      store(tiles, on: surface)
      return true
   }

   /// Every card back where it started, on every surface.
   func reset() {
      dashboardTiles = Self.defaultDashboardTiles
      trafficTiles = Self.defaultTrafficTiles
   }

   /// Restores a layout from a backup. Names are sanitized like a stored
   /// list; a missing list leaves that surface as it is.
   func restore(dashboard: [String]?, traffic: [String]?) {
      if let dashboard {
         dashboardTiles = Self.load(dashboard, fallback: Self.defaultDashboardTiles)
      }
      if let traffic {
         trafficTiles = Self.load(traffic, fallback: Self.defaultTrafficTiles)
      }
   }

   private func store(_ tiles: [RideCockpitMetric], on surface: RideCockpitSurface) {
      switch surface {
         case .dashboard: dashboardTiles = tiles
         case .traffic: trafficTiles = tiles
      }
   }
}
