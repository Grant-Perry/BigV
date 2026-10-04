//
//  RideBackupPayload.swift
//  BigV
//

import Foundation

/// Portable snapshot of rides and rider preferences for Settings backup/restore.
///
/// Versioned JSON so a future schema can migrate without breaking old files.
/// HealthKit workout links are omitted — they are device-local identifiers.
///
/// Laps and climb splits ride along as optional arrays: files written before
/// they were backed up decode with `nil` and restore without them, so the
/// format version stays at 1. Restore counts a ride only once it has saved.
nonisolated struct RideBackupPayload: Codable, Sendable {

   static let currentFormatVersion = 1

   var formatVersion: Int
   var exportedAt: Date
   var preferences: Preferences
   var rides: [RideRecord]

   // MARK: - Preferences

   struct Preferences: Codable, Sendable {
      var unitSystem: String
      var temperatureUnit: String
      var hasCompletedSetup: Bool
      var hasCompletedOnboarding: Bool
      var radarEnabled: Bool
      var radarPlacement: String
      var radarAlertHaptics: Bool
      var radarAlertAudio: Bool
      var radarToneStyle: String
      var radarClearTone: Bool
      var radarOverlayEnabled: Bool
      var radarDisclaimerAcknowledged: Bool

      /// Which metric sits in which cockpit card. Optional: backups from
      /// before cards could move have no layout, and decode as-is.
      var cockpitDashboardTiles: [String]?
      var cockpitTrafficTiles: [String]?
   }

   // MARK: - Ride

   struct RideRecord: Codable, Sendable {
      var startDate: Date
      var endDate: Date?
      var name: String
      var duration: TimeInterval
      var movingTime: TimeInterval
      var distance: Double
      var averageSpeed: Double
      var maximumSpeed: Double
      var elevationGain: Double
      var elevationLoss: Double
      var activeEnergy: Double?
      var averageHeartRate: Double?
      var averageCadence: Double?
      var averagePower: Double?
      var vehicleCount: Int
      var closestPassDistance: Double?
      var maximumClosingSpeed: Double?
      var weatherSymbolName: String?
      var weatherConditionLabel: String?
      var startTemperatureCelsius: Double?
      var startApparentTemperatureCelsius: Double?
      var windSpeedKilometersPerHour: Double?
      var endTemperatureCelsius: Double?
      var samples: [SampleRecord]
      var radarEvents: [RadarEventRecord]

      /// Optional: backups from before laps and climbs were included have none.
      var laps: [LapRecord]?
      var climbSplits: [ClimbSplitRecord]?
   }

   struct LapRecord: Codable, Sendable {
      var index: Int
      var startDate: Date
      var endDate: Date
      var startDistance: Double
      var endDistance: Double
      var distance: Double
      var duration: TimeInterval
      var elevationGain: Double
      var averageSpeed: Double
      var triggerRawValue: String
   }

   struct ClimbSplitRecord: Codable, Sendable {
      var index: Int
      var startDate: Date
      var endDate: Date
      var startDistance: Double
      var endDistance: Double
      var distance: Double
      var duration: TimeInterval
      var elevationGain: Double
      var averageSpeed: Double
      var averageGrade: Double
      var categoryRawValue: Int?
   }

   struct SampleRecord: Codable, Sendable {
      var timestamp: Date
      var latitude: Double
      var longitude: Double
      var altitude: Double
      var speed: Double
      var distance: Double
      var grade: Double
      var course: Double
      var heartRate: Double?
      var cadence: Double?
      var power: Double?
   }

   struct RadarEventRecord: Codable, Sendable {
      var timestamp: Date
      var trackID: Int
      var minimumDistance: Double
      var maximumClosingSpeed: Double
      var peakTierRawValue: Int
      var latitude: Double?
      var longitude: Double?
   }
}
