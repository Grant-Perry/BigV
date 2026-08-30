//
//  RideSchema.swift
//  BigV
//

import Foundation
import SwiftData

// MARK: - Migration Plan

/// The ride store's version history.
///
/// V1 → V2 is purely additive — a new `RideRadarEvent` model plus defaulted
/// radar totals on `Ride` — so the stage is lightweight. It is still declared
/// here explicitly: a store that migrates through a named plan can never be
/// stranded by a silent inference SwiftData declines to make, and the next
/// schema change has an obvious place to land.
enum RideMigrationPlan: SchemaMigrationPlan {

   static var schemas: [any VersionedSchema.Type] {
      [RideSchemaV1.self, RideSchemaV2.self, RideSchemaV3.self]
   }

   static var stages: [MigrationStage] {
      [migrateV1toV2, migrateV2toV3]
   }

   private static let migrateV1toV2 = MigrationStage.lightweight(
      fromVersion: RideSchemaV1.self,
      toVersion: RideSchemaV2.self
   )

   private static let migrateV2toV3 = MigrationStage.lightweight(
      fromVersion: RideSchemaV2.self,
      toVersion: RideSchemaV3.self
   )
}

// MARK: - V3 (current)

/// Gives a ride a memory of its sky: WeatherKit condition, start/end
/// temperature and wind, all optional so V2 rides migrate untouched.
///
/// The current version references the live model classes. When V4 arrives,
/// freeze this version by giving it nested snapshot models the way V1 and V2
/// do, and point the live classes at V4.
enum RideSchemaV3: VersionedSchema {

   static let versionIdentifier = Schema.Version(3, 0, 0)

   static var models: [any PersistentModel.Type] {
      [Ride.self, RideSample.self, RideRadarEvent.self]
   }
}

// MARK: - V2 (frozen)

/// Adds rear-radar memory: `RideRadarEvent` rows and pass totals on `Ride`.
///
/// These nested models are snapshots, not the live classes: they must never
/// change again, or migration from a V2 store breaks.
enum RideSchemaV2: VersionedSchema {

   static let versionIdentifier = Schema.Version(2, 0, 0)

   static var models: [any PersistentModel.Type] {
      [Ride.self, RideSample.self, RideRadarEvent.self]
   }

   @Model
   final class Ride {

      var startDate: Date = Date.distantPast
      var endDate: Date?
      var name: String = ""

      var duration: TimeInterval = 0
      var movingTime: TimeInterval = 0
      var distance: Double = 0
      var averageSpeed: Double = 0
      var maximumSpeed: Double = 0
      var elevationGain: Double = 0
      var elevationLoss: Double = 0

      var activeEnergy: Double?
      var averageHeartRate: Double?
      var averageCadence: Double?
      var averagePower: Double?

      var vehicleCount: Int = 0
      var closestPassDistance: Double?
      var maximumClosingSpeed: Double?

      var healthKitWorkoutID: UUID?

      @Relationship(deleteRule: .cascade, inverse: \RideSample.ride)
      var samples: [RideSample] = []

      @Relationship(deleteRule: .cascade, inverse: \RideRadarEvent.ride)
      var radarEvents: [RideRadarEvent] = []

      init(startDate: Date, name: String = "") {
         self.startDate = startDate
         self.name = name
      }
   }

   @Model
   final class RideSample {

      var timestamp: Date = Date.distantPast

      var latitude: Double = 0
      var longitude: Double = 0
      var altitude: Double = 0

      var speed: Double = 0
      var distance: Double = 0
      var grade: Double = 0
      var course: Double = -1

      var heartRate: Double?
      var cadence: Double?
      var power: Double?

      var ride: Ride?

      init(
         timestamp: Date,
         latitude: Double,
         longitude: Double,
         altitude: Double,
         speed: Double,
         distance: Double,
         grade: Double,
         course: Double
      ) {
         self.timestamp = timestamp
         self.latitude = latitude
         self.longitude = longitude
         self.altitude = altitude
         self.speed = speed
         self.distance = distance
         self.grade = grade
         self.course = course
      }
   }

   @Model
   final class RideRadarEvent {

      var timestamp: Date = Date.distantPast
      var trackID: Int = 0
      var minimumDistance: Double = 0
      var maximumClosingSpeed: Double = 0
      var peakTierRawValue: Int = RideRadarThreatTier.approaching.rawValue

      var latitude: Double?
      var longitude: Double?

      var ride: Ride?

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
}

// MARK: - V1 (frozen)

/// The shape the store shipped with, before the radar existed.
///
/// These nested models are snapshots, not the live classes: they must never
/// change again, or migration from a genuinely old store breaks. SwiftData
/// names entities by their unqualified type name, so `RideSchemaV1.Ride`
/// describes the same entity the live `Ride` does.
enum RideSchemaV1: VersionedSchema {

   static let versionIdentifier = Schema.Version(1, 0, 0)

   static var models: [any PersistentModel.Type] {
      [Ride.self, RideSample.self]
   }

   @Model
   final class Ride {

      var startDate: Date = Date.distantPast
      var endDate: Date?
      var name: String = ""

      var duration: TimeInterval = 0
      var movingTime: TimeInterval = 0
      var distance: Double = 0
      var averageSpeed: Double = 0
      var maximumSpeed: Double = 0
      var elevationGain: Double = 0
      var elevationLoss: Double = 0

      var activeEnergy: Double?
      var averageHeartRate: Double?
      var averageCadence: Double?
      var averagePower: Double?

      var healthKitWorkoutID: UUID?

      @Relationship(deleteRule: .cascade, inverse: \RideSample.ride)
      var samples: [RideSample] = []

      init(startDate: Date, name: String = "") {
         self.startDate = startDate
         self.name = name
      }
   }

   @Model
   final class RideSample {

      var timestamp: Date = Date.distantPast

      var latitude: Double = 0
      var longitude: Double = 0
      var altitude: Double = 0

      var speed: Double = 0
      var distance: Double = 0
      var grade: Double = 0
      var course: Double = -1

      var heartRate: Double?
      var cadence: Double?
      var power: Double?

      var ride: Ride?

      init(
         timestamp: Date,
         latitude: Double,
         longitude: Double,
         altitude: Double,
         speed: Double,
         distance: Double,
         grade: Double,
         course: Double
      ) {
         self.timestamp = timestamp
         self.latitude = latitude
         self.longitude = longitude
         self.altitude = altitude
         self.speed = speed
         self.distance = distance
         self.grade = grade
         self.course = course
      }
   }
}
