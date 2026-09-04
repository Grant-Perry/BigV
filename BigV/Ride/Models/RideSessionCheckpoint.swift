//
//  RideSessionCheckpoint.swift
//  BigV
//

import Foundation

/// What the app was in the middle of the last time it ran.
///
/// A ride row lives in SwiftData from the first GPS fix onward, so the numbers
/// already survive a termination on their own. What the row cannot say is
/// whether the rider had paused, and whether the app was killed mid-ride or shut
/// down cleanly — and that is the difference between resuming a ride and quietly
/// closing one out. This is that intent, written outside the store so it can be
/// read before SwiftData is even queried.
nonisolated struct RideSessionCheckpoint: Codable, Sendable, Equatable {

   /// Stored as the raw value so a future phase case cannot make an old
   /// checkpoint undecodable — an unknown phase reads back as `.idle`, which
   /// recovery treats as "nothing was running".
   let phaseRawValue: String

   /// The ride's first-fix date, used to prove the checkpoint and the open ride
   /// row are the same ride rather than two different interruptions.
   let startDate: Date?

   let updatedAt: Date

   var phase: RidePhase { RidePhase(rawValue: phaseRawValue) ?? .idle }

   init(phase: RidePhase, startDate: Date?, updatedAt: Date = .now) {
      self.phaseRawValue = phase.rawValue
      self.startDate = startDate
      self.updatedAt = updatedAt
   }
}

// MARK: - Store

/// Reads and writes the checkpoint. `UserDefaults` rather than the store: this
/// has to be readable at launch without faulting a single `Ride` in, and it has
/// to be writable from a scene that is already on its way out.
nonisolated struct RideSessionCheckpointStore {

   private static let key = "ride.session.checkpoint"

   private let defaults: UserDefaults

   init(defaults: UserDefaults = .standard) {
      self.defaults = defaults
   }

   func load() -> RideSessionCheckpoint? {
      guard let data = defaults.data(forKey: Self.key) else { return nil }
      return try? JSONDecoder().decode(RideSessionCheckpoint.self, from: data)
   }

   func write(_ checkpoint: RideSessionCheckpoint) {
      guard let data = try? JSONEncoder().encode(checkpoint) else { return }
      defaults.set(data, forKey: Self.key)
   }

   func clear() {
      defaults.removeObject(forKey: Self.key)
   }
}
