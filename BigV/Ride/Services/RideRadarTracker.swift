//
//  RideRadarTracker.swift
//  BigV
//

import Foundation

/// Turns raw radar frames into tracked vehicles, threat tiers, and alert edges.
///
/// Pure state machine with no framework side effects, mirroring
/// `RideTelemetryEngine`: `now` is injected on every call so tests are
/// deterministic. The wire's speed byte is untrustworthy across firmware
/// generations, so closing speed is derived here as a smoothed derivative of
/// distance — the radar reports at ~7 Hz, which makes that accurate and
/// unit-free.
struct RideRadarTracker {

   // MARK: - Configuration

   struct Configuration: Sendable {

      /// The radar itself tracks at most eight vehicles.
      var maxTracks = 8

      /// A track silent for this long has passed or vanished.
      var trackLifetime: TimeInterval = 2.0

      /// Distance is uint8-quantised to whole metres; smooth before deriving.
      var distanceSmoothingFactor: Double = 0.5

      var closingSpeedSmoothingFactor: Double = 0.35

      /// Closing speed at or above which a track escalates to `.high`.
      /// 8 m/s is roughly 18 mph of overtake.
      var highClosingSpeed: Double = 8

      /// Time-to-contact at or below which a track escalates to `.high`.
      var highTimeToContact: TimeInterval = 4

      /// Hysteresis floor: a `.high` track de-escalates only below this,
      /// so a car hovering at the boundary cannot strobe the UI.
      var exitClosingSpeed: Double = 6

      /// Hysteresis ceiling for time-to-contact on the way down.
      var exitTimeToContact: TimeInterval = 5.5

      /// Below this closing speed, time-to-contact is meaningless noise.
      var minimumClosingSpeedForContact: Double = 0.5

      static let `default` = Configuration()
   }

   // MARK: - Track

   struct Track: Sendable, Equatable, Identifiable {

      let id: UInt8

      /// Smoothed distance in metres.
      var distanceMeters: Double

      /// Derived, smoothed, in m/s. Negative means the vehicle is falling back.
      var closingSpeedMetersPerSecond: Double

      /// `nil` until the vehicle is genuinely closing.
      var timeToContact: TimeInterval?

      var tier: RideRadarThreatTier

      let firstSeenAt: Date
      var lastSeenAt: Date

      // Pass aggregation, carried on the track until it expires.
      var minimumDistanceMeters: Double
      var maximumClosingSpeedMetersPerSecond: Double
      var peakTier: RideRadarThreatTier
   }

   // MARK: - Pass

   /// One completed vehicle encounter, produced when its track expires.
   struct Pass: Sendable, Equatable {
      let trackID: UInt8
      let minimumDistanceMeters: Double
      let maximumClosingSpeedMetersPerSecond: Double
      let peakTier: RideRadarThreatTier
      let firstSeenAt: Date
      let lastSeenAt: Date
   }

   // MARK: - Events

   /// Edges, not levels. Alerting off levels buzzes continuously; alerting off
   /// edges taps once when something changes.
   enum Event: Sendable, Equatable {
      case threatEntered(trackID: UInt8)
      case tierEscalated(trackID: UInt8, tier: RideRadarThreatTier)
      case passCompleted(Pass)
      case allClear
   }

   // MARK: - Published State

   private(set) var tracks: [Track] = []

   /// Distinct vehicles that have come and gone this ride.
   private(set) var vehiclePassCount = 0

   private(set) var closestPassDistanceMeters: Double?
   private(set) var maximumClosingSpeedMetersPerSecond: Double = 0

   var nearestTrack: Track? {
      tracks.min { $0.distanceMeters < $1.distanceMeters }
   }

   /// The worst tier on the board, or `nil` when the road is empty.
   var aggregateTier: RideRadarThreatTier? {
      tracks.map(\.tier).max()
   }

   // MARK: - Private State

   private let configuration: Configuration

   // MARK: - Initialization

   init(configuration: Configuration = .default) {
      self.configuration = configuration
   }

   // MARK: - Lifecycle

   mutating func reset() {
      tracks.removeAll()
      vehiclePassCount = 0
      closestPassDistanceMeters = nil
      maximumClosingSpeedMetersPerSecond = 0
   }

   // MARK: - Ingestion

   /// Feeds one decoded frame in. Heartbeats carry no targets but still age
   /// the board, which is how an emptied road produces its all-clear.
   mutating func ingest(_ frame: RideRadarFrame, at now: Date) -> [Event] {
      var events: [Event] = []

      for reading in frame.targets {
         if let index = tracks.firstIndex(where: { $0.id == reading.trackID }) {
            update(at: index, with: reading, at: now, events: &events)
         } else if tracks.count < configuration.maxTracks {
            tracks.append(newTrack(for: reading, at: now))
            events.append(.threatEntered(trackID: reading.trackID))
         }
      }

      events.append(contentsOf: expireStaleTracks(at: now))
      return events
   }

   /// Ages the board without a frame — for the session's 1 Hz tick, so a radar
   /// that goes silent cannot leave phantom vehicles on screen.
   mutating func expireStaleTracks(at now: Date) -> [Event] {
      let hadTracks = !tracks.isEmpty
      var events: [Event] = []

      let expired = tracks.filter {
         now.timeIntervalSince($0.lastSeenAt) > configuration.trackLifetime
      }

      guard !expired.isEmpty else { return events }

      tracks.removeAll { track in
         expired.contains { $0.id == track.id && $0.lastSeenAt == track.lastSeenAt }
      }

      for track in expired {
         let pass = Pass(
            trackID: track.id,
            minimumDistanceMeters: track.minimumDistanceMeters,
            maximumClosingSpeedMetersPerSecond: track.maximumClosingSpeedMetersPerSecond,
            peakTier: track.peakTier,
            firstSeenAt: track.firstSeenAt,
            lastSeenAt: track.lastSeenAt
         )

         vehiclePassCount += 1
         closestPassDistanceMeters = min(
            closestPassDistanceMeters ?? .greatestFiniteMagnitude,
            pass.minimumDistanceMeters
         )
         maximumClosingSpeedMetersPerSecond = max(
            maximumClosingSpeedMetersPerSecond,
            pass.maximumClosingSpeedMetersPerSecond
         )

         events.append(.passCompleted(pass))
      }

      if hadTracks && tracks.isEmpty {
         events.append(.allClear)
      }

      return events
   }

   // MARK: - Track Updates

   private func newTrack(for reading: RideRadarTargetReading, at now: Date) -> Track {
      Track(
         id: reading.trackID,
         distanceMeters: reading.distanceMeters,
         closingSpeedMetersPerSecond: 0,
         timeToContact: nil,
         tier: .approaching,
         firstSeenAt: now,
         lastSeenAt: now,
         minimumDistanceMeters: reading.distanceMeters,
         maximumClosingSpeedMetersPerSecond: 0,
         peakTier: .approaching
      )
   }

   private mutating func update(
      at index: Int,
      with reading: RideRadarTargetReading,
      at now: Date,
      events: inout [Event]
   ) {
      var track = tracks[index]
      let interval = now.timeIntervalSince(track.lastSeenAt)

      guard interval > 0.01 else { return }

      let previousDistance = track.distanceMeters
      track.distanceMeters += (reading.distanceMeters - track.distanceMeters)
         * configuration.distanceSmoothingFactor

      let instantaneousClosing = (previousDistance - track.distanceMeters) / interval
      track.closingSpeedMetersPerSecond += (instantaneousClosing - track.closingSpeedMetersPerSecond)
         * configuration.closingSpeedSmoothingFactor

      track.timeToContact = timeToContact(
         distance: track.distanceMeters,
         closingSpeed: track.closingSpeedMetersPerSecond
      )

      let previousTier = track.tier
      track.tier = tier(for: track)

      track.lastSeenAt = now
      track.minimumDistanceMeters = min(track.minimumDistanceMeters, track.distanceMeters)
      track.maximumClosingSpeedMetersPerSecond = max(
         track.maximumClosingSpeedMetersPerSecond,
         track.closingSpeedMetersPerSecond
      )
      track.peakTier = max(track.peakTier, track.tier)

      tracks[index] = track

      if track.tier > previousTier {
         events.append(.tierEscalated(trackID: track.id, tier: track.tier))
      }
   }

   // MARK: - Threat Model

   private func timeToContact(distance: Double, closingSpeed: Double) -> TimeInterval? {
      guard closingSpeed >= configuration.minimumClosingSpeedForContact else { return nil }
      return distance / closingSpeed
   }

   /// Escalation and de-escalation use different thresholds on purpose.
   private func tier(for track: Track) -> RideRadarThreatTier {
      let closing = track.closingSpeedMetersPerSecond
      let contact = track.timeToContact

      switch track.tier {
         case .approaching:
            let fastApproach = closing >= configuration.highClosingSpeed
            let imminent = contact.map { $0 <= configuration.highTimeToContact } ?? false
            return (fastApproach || imminent) ? .high : .approaching

         case .high:
            let calmed = closing < configuration.exitClosingSpeed
            let distant = contact.map { $0 > configuration.exitTimeToContact } ?? true
            return (calmed && distant) ? .approaching : .high
      }
   }
}
