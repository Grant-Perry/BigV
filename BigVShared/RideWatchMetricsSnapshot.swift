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
   let locationIssue: String?
   let horizontalAccuracy: Double?

   /// The phone's measurement-system preference, mirrored so wrist labels
   /// always match the phone. Imperial when the key predates the units
   /// feature — the app's default.
   let unitSystem: RideUnitSystem

   // MARK: - Radar

   /// The rear radar's contribution, every field optional so a build on either
   /// side that predates the radar decodes the rest of the mirror untouched.
   /// `radarConnected` doubles as the presence marker: `nil` means the phone
   /// has no radar in play at all, distinct from a radar that dropped its link.
   let radarConnected: Bool?
   let radarTier: RideRadarThreatTier?
   let radarCount: Int?
   let radarNearest: Double?
   let radarAlertPulse: Int?
   let radarClearPulse: Int?

   // MARK: - Initialization

   init(
      phase: RidePhase,
      speed: Double,
      distance: Double,
      elapsedTime: TimeInterval,
      hasGPSFix: Bool,
      isMoving: Bool,
      capturedAt: Date = .now,
      locationIssue: String? = nil,
      horizontalAccuracy: Double? = nil,
      unitSystem: RideUnitSystem = .imperial,
      radarConnected: Bool? = nil,
      radarTier: RideRadarThreatTier? = nil,
      radarCount: Int? = nil,
      radarNearest: Double? = nil,
      radarAlertPulse: Int? = nil,
      radarClearPulse: Int? = nil
   ) {
      self.phase = phase
      self.speed = speed
      self.distance = distance
      self.elapsedTime = elapsedTime
      self.hasGPSFix = hasGPSFix
      self.isMoving = isMoving
      self.capturedAt = capturedAt
      self.locationIssue = locationIssue
      self.horizontalAccuracy = horizontalAccuracy
      self.unitSystem = unitSystem
      self.radarConnected = radarConnected
      self.radarTier = radarTier
      self.radarCount = radarCount
      self.radarNearest = radarNearest
      self.radarAlertPulse = radarAlertPulse
      self.radarClearPulse = radarClearPulse
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
      static let locationIssue = "locationIssue"
      static let horizontalAccuracy = "horizontalAccuracy"
      static let units = "units"
      static let radarConnected = "radarConnected"
      static let radarTier = "radarTier"
      static let radarCount = "radarCount"
      static let radarNearest = "radarNearest"
      static let radarAlertPulse = "radarAlertPulse"
      static let radarClearPulse = "radarClearPulse"
   }

   var body: [String: Any] {
      var payload: [String: Any] = [
         Key.phase: phase.rawValue,
         Key.speed: speed,
         Key.distance: distance,
         Key.elapsedTime: elapsedTime,
         Key.hasGPSFix: hasGPSFix,
         Key.isMoving: isMoving,
         Key.capturedAt: capturedAt.timeIntervalSince1970,
         Key.units: unitSystem.rawValue
      ]

      if let locationIssue {
         payload[Key.locationIssue] = locationIssue
      }

      if let horizontalAccuracy {
         payload[Key.horizontalAccuracy] = horizontalAccuracy
      }

      if let radarConnected {
         payload[Key.radarConnected] = radarConnected
      }

      if let radarTier {
         payload[Key.radarTier] = radarTier.rawValue
      }

      if let radarCount {
         payload[Key.radarCount] = radarCount
      }

      if let radarNearest {
         payload[Key.radarNearest] = radarNearest
      }

      if let radarAlertPulse {
         payload[Key.radarAlertPulse] = radarAlertPulse
      }

      if let radarClearPulse {
         payload[Key.radarClearPulse] = radarClearPulse
      }

      return payload
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
      self.locationIssue = body[Key.locationIssue] as? String
      self.horizontalAccuracy = body[Key.horizontalAccuracy] as? Double
      self.unitSystem = (body[Key.units] as? String)
         .flatMap(RideUnitSystem.init) ?? .imperial
      self.radarConnected = body[Key.radarConnected] as? Bool
      self.radarTier = (body[Key.radarTier] as? Int).flatMap(RideRadarThreatTier.init)
      self.radarCount = body[Key.radarCount] as? Int
      self.radarNearest = body[Key.radarNearest] as? Double
      self.radarAlertPulse = body[Key.radarAlertPulse] as? Int
      self.radarClearPulse = body[Key.radarClearPulse] as? Int
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
