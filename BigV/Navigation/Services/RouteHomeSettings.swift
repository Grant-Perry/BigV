//
//  RouteHomeSettings.swift
//  BigV
//

import Foundation
import Observation

/// The rider's home address, observable and persisted.
///
/// Same shape as `RideClimbSettings`: UserDefaults cannot notify `@Observable`
/// tracking, so the value is a stored mirror loaded once and written through on
/// set. Only the destination is kept — Apple plans the way home from wherever
/// the rider happens to be.
@Observable
@MainActor
final class RouteHomeSettings {

   // MARK: - Keys

   private enum Key {
      static let home = "route.home.v1"
   }

   @ObservationIgnored private let defaults: UserDefaults

   // MARK: - Preferences

   /// Where home is, or `nil` until the rider sets it.
   var home: RouteDestination? {
      didSet { persist() }
   }

   var hasHome: Bool { home != nil }

   /// The one-line form for a button or a settings row.
   var homeLabel: String? {
      guard let home else { return nil }
      return home.detail ?? home.name
   }

   // MARK: - Initialization

   init(defaults: UserDefaults = .standard) {
      self.defaults = defaults
      home = Self.load(from: defaults)
   }

   // MARK: - Intent

   func clearHome() {
      home = nil
   }

   // MARK: - Persistence

   private static func load(from defaults: UserDefaults) -> RouteDestination? {
      guard let data = defaults.data(forKey: Key.home) else { return nil }

      do {
         return try JSONDecoder().decode(RouteDestinationRecord.self, from: data).routeDestination
      } catch {
         DebugPrint(mode: .persistence, "Home address decode failed: \(error)")
         return nil
      }
   }

   private func persist() {
      guard let home else {
         defaults.removeObject(forKey: Key.home)
         return
      }

      do {
         defaults.set(try JSONEncoder().encode(RouteDestinationRecord(home)), forKey: Key.home)
      } catch {
         DebugPrint(mode: .persistence, "Home address encode failed: \(error)")
      }
   }
}
