//
//  RideBackupManager.swift
//  BigV
//

import Foundation
import UniformTypeIdentifiers

/// Builds and applies Settings backups: finished rides plus rider preferences.
///
/// Restore merges rides that are not already present (matched by start, distance
/// and duration). Preferences always overwrite. An active recording blocks restore
/// so an in-progress row cannot collide with imported history.
@MainActor
final class RideBackupManager {

   // MARK: - Results

   struct ExportResult: Sendable {
      let url: URL
      let rideCount: Int
   }

   struct ImportResult: Sendable {
      let addedRideCount: Int
      let skippedRideCount: Int
   }

   enum BackupError: LocalizedError {
      case rideInProgress
      case unsupportedVersion(Int)
      case decodeFailed
      case emptyFile

      var errorDescription: String? {
         switch self {
            case .rideInProgress:
               "End the current ride before restoring a backup."
            case .unsupportedVersion(let version):
               "This backup format (v\(version)) is not supported."
            case .decodeFailed:
               "Could not read that backup file."
            case .emptyFile:
               "That backup file is empty."
         }
      }
   }

   // MARK: - Dependencies

   private let rideStorageManager: RideStorageManager
   private let unitsSettings: RideUnitsSettings
   private let radarSettings: RideRadarSettings
   private let onboardingSettings: RideOnboardingSettings

   // MARK: - Initialization

   init(
      rideStorageManager: RideStorageManager,
      unitsSettings: RideUnitsSettings,
      radarSettings: RideRadarSettings,
      onboardingSettings: RideOnboardingSettings
   ) {
      self.rideStorageManager = rideStorageManager
      self.unitsSettings = unitsSettings
      self.radarSettings = radarSettings
      self.onboardingSettings = onboardingSettings
   }

   // MARK: - Export

   func exportBackup() throws -> ExportResult {
      let rides = rideStorageManager.savedRides().filter { $0.endDate != nil }
      let payload = RideBackupPayload(
         formatVersion: RideBackupPayload.currentFormatVersion,
         exportedAt: .now,
         preferences: snapshotPreferences(),
         rides: rides.map(Self.encode(ride:))
      )

      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

      let data = try encoder.encode(payload)
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.dateFormat = "yyyy-MM-dd-HHmm"
      let name = "BigVelo-Backup-\(formatter.string(from: .now)).json"
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
      try data.write(to: url, options: .atomic)

      DebugPrint(mode: .persistence, "Backup exported \(rides.count) rides → \(name)")
      return ExportResult(url: url, rideCount: rides.count)
   }

   // MARK: - Import

   func importBackup(from url: URL, rideInProgress: Bool) throws -> ImportResult {
      guard !rideInProgress else { throw BackupError.rideInProgress }

      let accessed = url.startAccessingSecurityScopedResource()
      defer {
         if accessed { url.stopAccessingSecurityScopedResource() }
      }

      let data = try Data(contentsOf: url)
      guard !data.isEmpty else { throw BackupError.emptyFile }

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601

      let payload: RideBackupPayload
      do {
         payload = try decoder.decode(RideBackupPayload.self, from: data)
      } catch {
         DebugPrint(mode: .persistence, "Backup decode failed: \(error.localizedDescription)")
         throw BackupError.decodeFailed
      }

      guard payload.formatVersion == RideBackupPayload.currentFormatVersion else {
         throw BackupError.unsupportedVersion(payload.formatVersion)
      }

      apply(preferences: payload.preferences)

      let existing = rideStorageManager.savedRides()
      let existingKeys = Set(existing.map(Self.identityKey(for:)))

      var added = 0
      var skipped = 0

      for record in payload.rides {
         let key = Self.identityKey(
            startDate: record.startDate,
            distance: record.distance,
            duration: record.duration
         )
         if existingKeys.contains(key) {
            skipped += 1
            continue
         }

         rideStorageManager.importFinishedRide(record)
         added += 1
      }

      DebugPrint(
         mode: .persistence,
         "Backup restored +\(added) rides, skipped \(skipped), prefs applied"
      )
      return ImportResult(addedRideCount: added, skippedRideCount: skipped)
   }

   // MARK: - Preferences

   private func snapshotPreferences() -> RideBackupPayload.Preferences {
      RideBackupPayload.Preferences(
         unitSystem: unitsSettings.system.rawValue,
         temperatureUnit: unitsSettings.temperatureUnit.rawValue,
         hasCompletedSetup: unitsSettings.hasCompletedSetup,
         hasCompletedOnboarding: onboardingSettings.hasCompletedOnboarding,
         radarEnabled: radarSettings.isEnabled,
         radarPlacement: radarSettings.placement.rawValue,
         radarAlertHaptics: radarSettings.alertHapticsEnabled,
         radarAlertAudio: radarSettings.alertAudioEnabled,
         radarToneStyle: radarSettings.toneStyle.rawValue,
         radarClearTone: radarSettings.clearToneEnabled,
         radarOverlayEnabled: radarSettings.overlayEnabled,
         radarDisclaimerAcknowledged: radarSettings.hasAcknowledgedDisclaimer
      )
   }

   private func apply(preferences: RideBackupPayload.Preferences) {
      if let system = RideUnitSystem(rawValue: preferences.unitSystem) {
         unitsSettings.system = system
      }
      if let temperature = RideTemperatureUnit(rawValue: preferences.temperatureUnit) {
         unitsSettings.temperatureUnit = temperature
      }
      unitsSettings.hasCompletedSetup = preferences.hasCompletedSetup
      onboardingSettings.hasCompletedOnboarding = preferences.hasCompletedOnboarding

      radarSettings.isEnabled = preferences.radarEnabled
      if let placement = RideRadarPlacement(rawValue: preferences.radarPlacement) {
         radarSettings.placement = placement
      }
      radarSettings.alertHapticsEnabled = preferences.radarAlertHaptics
      radarSettings.alertAudioEnabled = preferences.radarAlertAudio
      if let tone = RideRadarToneStyle(rawValue: preferences.radarToneStyle) {
         radarSettings.toneStyle = tone
      }
      radarSettings.clearToneEnabled = preferences.radarClearTone
      radarSettings.overlayEnabled = preferences.radarOverlayEnabled
      radarSettings.hasAcknowledgedDisclaimer = preferences.radarDisclaimerAcknowledged
   }

   // MARK: - Encoding

   private static func encode(ride: Ride) -> RideBackupPayload.RideRecord {
      RideBackupPayload.RideRecord(
         startDate: ride.startDate,
         endDate: ride.endDate,
         name: ride.name,
         duration: ride.duration,
         movingTime: ride.movingTime,
         distance: ride.distance,
         averageSpeed: ride.averageSpeed,
         maximumSpeed: ride.maximumSpeed,
         elevationGain: ride.elevationGain,
         elevationLoss: ride.elevationLoss,
         activeEnergy: ride.activeEnergy,
         averageHeartRate: ride.averageHeartRate,
         averageCadence: ride.averageCadence,
         averagePower: ride.averagePower,
         vehicleCount: ride.vehicleCount,
         closestPassDistance: ride.closestPassDistance,
         maximumClosingSpeed: ride.maximumClosingSpeed,
         weatherSymbolName: ride.weatherSymbolName,
         weatherConditionLabel: ride.weatherConditionLabel,
         startTemperatureCelsius: ride.startTemperatureCelsius,
         startApparentTemperatureCelsius: ride.startApparentTemperatureCelsius,
         windSpeedKilometersPerHour: ride.windSpeedKilometersPerHour,
         endTemperatureCelsius: ride.endTemperatureCelsius,
         samples: ride.samples
            .sorted { $0.timestamp < $1.timestamp }
            .map(encode(sample:)),
         radarEvents: ride.radarEvents
            .sorted { $0.timestamp < $1.timestamp }
            .map(encode(event:))
      )
   }

   private static func encode(sample: RideSample) -> RideBackupPayload.SampleRecord {
      RideBackupPayload.SampleRecord(
         timestamp: sample.timestamp,
         latitude: sample.latitude,
         longitude: sample.longitude,
         altitude: sample.altitude,
         speed: sample.speed,
         distance: sample.distance,
         grade: sample.grade,
         course: sample.course,
         heartRate: sample.heartRate,
         cadence: sample.cadence,
         power: sample.power
      )
   }

   private static func encode(event: RideRadarEvent) -> RideBackupPayload.RadarEventRecord {
      RideBackupPayload.RadarEventRecord(
         timestamp: event.timestamp,
         trackID: event.trackID,
         minimumDistance: event.minimumDistance,
         maximumClosingSpeed: event.maximumClosingSpeed,
         peakTierRawValue: event.peakTierRawValue,
         latitude: event.latitude,
         longitude: event.longitude
      )
   }

   private static func identityKey(for ride: Ride) -> String {
      identityKey(startDate: ride.startDate, distance: ride.distance, duration: ride.duration)
   }

   private static func identityKey(startDate: Date, distance: Double, duration: TimeInterval) -> String {
      let start = Int(startDate.timeIntervalSince1970)
      let meters = Int(distance.rounded())
      let seconds = Int(duration.rounded())
      return "\(start)-\(meters)-\(seconds)"
   }
}

// MARK: - UTType

extension UTType {
   static let bigVeloBackup = UTType.json
}
