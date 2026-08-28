//
//  RideRadarEvent.swift
//  BigV
//

import Foundation
import SwiftData

/// One completed vehicle pass recorded during a ride.
///
/// Written when the tracker expires a track — never per BLE frame — so volume
/// stays naturally low: a long road ride produces dozens of rows, not thousands.
/// Only `RideStorageManager` may insert or delete these.
@Model
final class RideRadarEvent {

   /// When the vehicle was last seen, which is the moment the pass completed.
   var timestamp: Date = Date.distantPast

   /// The radar's track id for this vehicle. Ids recycle between passes, so
   /// this is diagnostic, not identity.
   var trackID: Int = 0

   /// Closest approach in meters.
   var minimumDistance: Double = 0

   /// Fastest derived closing speed in meters/second.
   var maximumClosingSpeed: Double = 0

   /// Raw value of the worst `RideRadarThreatTier` the pass reached. Stored
   /// raw so a future tier never breaks the schema.
   var peakTierRawValue: Int = RideRadarThreatTier.approaching.rawValue

   // MARK: - Rider Position

   /// Where the rider was when the pass completed. `nil` when GPS had not
   /// produced an accepted sample yet.
   var latitude: Double?
   var longitude: Double?

   // MARK: - Relationship

   var ride: Ride?

   // MARK: - Derived

   var peakTier: RideRadarThreatTier {
      RideRadarThreatTier(rawValue: peakTierRawValue) ?? .approaching
   }

   // MARK: - Initialization

   init(
      timestamp: Date,
      trackID: Int,
      minimumDistance: Double,
      maximumClosingSpeed: Double,
      peakTier: RideRadarThreatTier,
      latitude: Double?,
      longitude: Double?
   ) {
      self.timestamp = timestamp
      self.trackID = trackID
      self.minimumDistance = minimumDistance
      self.maximumClosingSpeed = maximumClosingSpeed
      self.peakTierRawValue = peakTier.rawValue
      self.latitude = latitude
      self.longitude = longitude
   }
}
