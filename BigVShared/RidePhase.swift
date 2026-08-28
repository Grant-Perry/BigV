//
//  RidePhase.swift
//  BigV
//

import Foundation

/// Lifecycle of a single ride session.
nonisolated enum RidePhase: String, Sendable, CaseIterable {

   /// No ride in progress.
   case idle

   /// Rider pressed start; waiting for a usable GPS fix before recording.
   case acquiringGPS

   /// Actively recording telemetry.
   case recording

   /// Recording suspended by the rider.
   case paused

   /// Ride complete and awaiting review.
   case finished

   /// Whether a ride is underway, recording or not.
   var isActive: Bool {
      switch self {
         case .acquiringGPS, .recording, .paused: true
         case .idle, .finished: false
      }
   }

   /// Whether telemetry samples should be ingested.
   var acceptsTelemetry: Bool {
      switch self {
         case .acquiringGPS, .recording: true
         case .idle, .paused, .finished: false
      }
   }
}
