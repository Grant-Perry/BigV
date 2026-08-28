//
//  RideWatchMetricsSnapshot.swift
//  BigVShared
//

import Foundation

/// The slice of the phone's ride the wrist is allowed to see.
///
/// Deliberately thin. The phone owns GPS, recording and every derived metric;
/// this is a read-only glance, in the same SI units the engine works in, so the
/// Watch never does ride math. `capturedAt` lets the Watch tell live truth from
/// a snapshot that has been sitting in the application context since the wrist
/// went down.
nonisolated struct RideWatchMetricsSnapshot: Sendable, Equatable {

   let phase: RidePhase
   let speed: Double
   let distance: Double
   let elapsedTime: TimeInterval
   let hasGPSFix: Bool
   let isMoving: Bool
   let capturedAt: Date

   // MARK: - Initialization

   init(
      phase: RidePhase,
      speed: Double,
      distance: Double,
      elapsedTime: TimeInterval,
      hasGPSFix: Bool,
      isMoving: Bool,
      capturedAt: Date = .now
   ) {
      self.phase = phase
      self.speed = speed
      self.distance = distance
      self.elapsedTime = elapsedTime
      self.hasGPSFix = hasGPSFix
      self.isMoving = isMoving
      self.capturedAt = capturedAt
   }

   // MARK: - Wire Format

   private enum Key {
      static let phase = "phase"
      static let speed = "speed"
      static let distance = "distance"
      static let elapsedTime = "elapsedTime"
      static let hasGPSFix = "hasGPSFix"
      static let isMoving = "isMoving"
      static let capturedAt = "capturedAt"
   }

   var body: [String: Any] {
      [
         Key.phase: phase.rawValue,
         Key.speed: speed,
         Key.distance: distance,
         Key.elapsedTime: elapsedTime,
         Key.hasGPSFix: hasGPSFix,
         Key.isMoving: isMoving,
         Key.capturedAt: capturedAt.timeIntervalSince1970
      ]
   }

   init?(body: [String: Any]) {
      guard let rawPhase = body[Key.phase] as? String,
            let phase = RidePhase(rawValue: rawPhase),
            let speed = body[Key.speed] as? Double,
            let distance = body[Key.distance] as? Double,
            let elapsedTime = body[Key.elapsedTime] as? Double,
            let hasGPSFix = body[Key.hasGPSFix] as? Bool,
            let isMoving = body[Key.isMoving] as? Bool,
            let capturedAt = body[Key.capturedAt] as? Double
      else { return nil }

      self.phase = phase
      self.speed = speed
      self.distance = distance
      self.elapsedTime = elapsedTime
      self.hasGPSFix = hasGPSFix
      self.isMoving = isMoving
      self.capturedAt = Date(timeIntervalSince1970: capturedAt)
   }

   // MARK: - Freshness

   /// Whether this snapshot is recent enough to present as live.
   ///
   /// An application-context payload survives unreachability by design, so it
   /// can be arbitrarily old by the time the Watch reads it.
   func isFresh(at instant: Date = .now, within window: TimeInterval = 8) -> Bool {
      abs(instant.timeIntervalSince(capturedAt)) <= window
   }
}
