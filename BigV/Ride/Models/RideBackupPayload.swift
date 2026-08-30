//
//  RideBackupPayload.swift
//  BigV
//

import Foundation

/// Portable snapshot of rides and rider preferences for Settings backup/restore.
///
/// Versioned JSON so a future schema can migrate without breaking old files.
/// HealthKit workout links are omitted — they are device-local identifiers.
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
