//
//  RideRadarSnapshot.swift
//  BigV
//

import Foundation

/// The radar's contribution to `RideState`: what is behind the rider right now.
///
/// Tracks are capped at eight and cheap to diff, so this rides the same
/// Equatable republish gate as the rest of the state without thrashing SwiftUI.
struct RideRadarSnapshot: Sendable, Equatable {

   var connection: RideRadarConnectionState = .disconnected

   /// Live vehicles, at most eight, nearest decides the readout.
   var tracks: [RideRadarTracker.Track] = []

   /// The worst tier on the board, `nil` when the road is empty.
   var aggregateTier: RideRadarThreatTier?

   var nearestDistanceMeters: Double?
   var nearestClosingSpeedMetersPerSecond: Double?

   /// Completed vehicle passes this ride.
   var vehiclePassCount = 0

   // MARK: - Per-Ride Pass Aggregates

   /// Closest completed pass this ride, in meters. Written by the session as
   /// passes persist, so the post-ride summary reads radar totals from the
   /// same state as every other total. `nil` until a pass completes while
   /// recording.
   var closestPassDistanceMeters: Double?

   /// Fastest closing speed across this ride's completed passes, in m/s.
   var maximumPassClosingSpeedMetersPerSecond: Double?

   var batteryPercent: Int?
   var issue: RideRadarIssue?

   // MARK: - Alert Pulses

   /// Monotonic counters for `.sensoryFeedback(_:trigger:)`, matching the
   /// `turnPulse` pattern: bump on the edge, never reset mid-ride, and the
   /// view layer needs no timers to know something just happened.
   var alertPulse = 0
   var clearPulse = 0

   // MARK: - Convenience

   var isConnected: Bool { connection.isConnected }
   var hasVehicles: Bool { !tracks.isEmpty }
}
