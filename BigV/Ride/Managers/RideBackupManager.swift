//
//  RideBackupManager.swift
//  BigV
//

import CoreLocation
import Foundation
import UniformTypeIdentifiers

/// Builds and applies Settings backups: finished rides plus rider preferences.
///
/// Restore inserts finished rides that are not already present (matched by
/// start, distance and duration). A match missing children the file has is
/// filled in place and counted as an update; a complete match is skipped.
/// Preferences always overwrite. Extended preferences are absent on older
/// files, and those files leave places and the newer switches untouched.
/// An active recording blocks restore.
@MainActor
final class RideBackupManager {

   // MARK: - Results

   struct ExportResult: Sendable {
      let url: URL
      let rideCount: Int
   }

   struct ImportResult: Sendable {
      let addedRideCount: Int
      let updatedRideCount: Int
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
   private let cockpitLayoutSettings: RideCockpitLayoutSettings
   private let appearanceSettings: RideAppearanceSettings
   private let lapSettings: RideLapSettings
   private let climbSettings: RideClimbSettings
   private let routeHomeSettings: RouteHomeSettings
   private let routeFavoriteStore: RouteFavoriteStore
   private let routeRecentStore: RouteRecentStore
   private let routeGuidanceManager: RouteGuidanceManager
   private let weatherModel: RideWeatherModel
   private let defaults: UserDefaults

   // MARK: - Initialization

   init(
      rideStorageManager: RideStorageManager,
      unitsSettings: RideUnitsSettings,
      radarSettings: RideRadarSettings,
      onboardingSettings: RideOnboardingSettings,
      cockpitLayoutSettings: RideCockpitLayoutSettings,
      appearanceSettings: RideAppearanceSettings,
      lapSettings: RideLapSettings,
      climbSettings: RideClimbSettings,
      routeHomeSettings: RouteHomeSettings,
      routeFavoriteStore: RouteFavoriteStore,
      routeRecentStore: RouteRecentStore,
      routeGuidanceManager: RouteGuidanceManager,
      weatherModel: RideWeatherModel,
      defaults: UserDefaults = .standard
   ) {
      self.rideStorageManager = rideStorageManager
      self.unitsSettings = unitsSettings
      self.radarSettings = radarSettings
      self.onboardingSettings = onboardingSettings
      self.cockpitLayoutSettings = cockpitLayoutSettings
      self.appearanceSettings = appearanceSettings
      self.lapSettings = lapSettings
      self.climbSettings = climbSettings
      self.routeHomeSettings = routeHomeSettings
      self.routeFavoriteStore = routeFavoriteStore
      self.routeRecentStore = routeRecentStore
      self.routeGuidanceManager = routeGuidanceManager
      self.weatherModel = weatherModel
      self.defaults = defaults
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
      var existingByKey: [String: Ride] = [:]
      for ride in existing {
         let key = Self.identityKey(for: ride)
         if existingByKey[key] == nil {
            existingByKey[key] = ride
         }
      }

      var added = 0
      var updated = 0
      var skipped = 0
      var failed = 0

      for record in payload.rides {
         let key = Self.identityKey(
            startDate: record.startDate,
            distance: record.distance,
            duration: record.duration
         )
         if let ride = existingByKey[key] {
            switch rideStorageManager.fillMissingContent(on: ride, from: record) {
               case .unchanged:
                  skipped += 1
               case .updated:
                  updated += 1
               case .failed:
                  failed += 1
            }
            continue
         }

         guard rideStorageManager.importFinishedRide(record) else {
            failed += 1
            continue
         }
         added += 1
      }

      DebugPrint(
         mode: .persistence,
         "Backup restored +\(added) rides, updated \(updated), skipped \(skipped), failed \(failed), prefs applied"
      )
      return ImportResult(
         addedRideCount: added,
         updatedRideCount: updated,
         skippedRideCount: skipped
      )
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
         radarDisclaimerAcknowledged: radarSettings.hasAcknowledgedDisclaimer,
         cockpitDashboardTiles: cockpitLayoutSettings.dashboardTiles.map(\.rawValue),
         cockpitTrafficTiles: cockpitLayoutSettings.trafficTiles.map(\.rawValue),
         extended: snapshotExtendedPreferences()
      )
   }

   private func snapshotExtendedPreferences() -> RideBackupPayload.ExtendedPreferences {
      RideBackupPayload.ExtendedPreferences(
         home: routeHomeSettings.home.map(RouteDestinationRecord.init),
         favorites: routeFavoriteStore.favorites,
         recents: routeRecentStore.recents,
         weatherPin: snapshotWeatherPin(),
         appearanceMode: appearanceSettings.mode.rawValue,
         autoLapUnits: lapSettings.autoLapUnits,
         climbAutoSwitchEnabled: climbSettings.autoSwitchEnabled,
         guidanceVoiceEnabled: routeGuidanceManager.isVoiceEnabled,
         favoritesSectionExpanded: RouteFavoriteSectionPreferences.isExpanded(in: defaults),
         recentsSectionExpanded: RouteRecentSectionPreferences.isExpanded(in: defaults)
      )
   }

   private func snapshotWeatherPin() -> RideBackupPayload.WeatherPinRecord? {
      guard let place = RideWeatherPlaceStore.pinnedPlace(in: defaults) else { return nil }
      return RideBackupPayload.WeatherPinRecord(
         latitude: place.latitude,
         longitude: place.longitude,
         label: place.label,
         timeZoneIdentifier: place.timeZoneIdentifier
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

      cockpitLayoutSettings.restore(
         dashboard: preferences.cockpitDashboardTiles,
         traffic: preferences.cockpitTrafficTiles
      )

      if let extended = preferences.extended {
         apply(extended: extended)
      }
   }

   private func apply(extended: RideBackupPayload.ExtendedPreferences) {
      routeHomeSettings.home = extended.home?.routeDestination
      routeFavoriteStore.replace(extended.favorites)
      routeRecentStore.replace(extended.recents)

      if let pin = extended.weatherPin {
         let place = RideWeatherPlace.pinned(
            coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
            label: pin.label,
            timeZone: pin.timeZoneIdentifier.flatMap(TimeZone.init(identifier:))
         )
         weatherModel.restorePinnedPlace(place, defaults: defaults)
      } else {
         weatherModel.restorePinnedPlace(nil, defaults: defaults)
      }

      if let mode = RideAppearanceMode(rawValue: extended.appearanceMode) {
         appearanceSettings.mode = mode
      }
      lapSettings.autoLapUnits = extended.autoLapUnits
      climbSettings.autoSwitchEnabled = extended.climbAutoSwitchEnabled
      routeGuidanceManager.isVoiceEnabled = extended.guidanceVoiceEnabled
      RouteFavoriteSectionPreferences.setExpanded(extended.favoritesSectionExpanded, in: defaults)
      RouteRecentSectionPreferences.setExpanded(extended.recentsSectionExpanded, in: defaults)
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
            .map(encode(event:)),
         laps: ride.laps
            .sorted { $0.index < $1.index }
            .map(encode(lap:)),
         climbSplits: ride.climbSplits
            .sorted { $0.index < $1.index }
            .map(encode(split:))
      )
   }

   private static func encode(lap: RideLap) -> RideBackupPayload.LapRecord {
      RideBackupPayload.LapRecord(
         index: lap.index,
         startDate: lap.startDate,
         endDate: lap.endDate,
         startDistance: lap.startDistance,
         endDistance: lap.endDistance,
         distance: lap.distance,
         duration: lap.duration,
         elevationGain: lap.elevationGain,
         averageSpeed: lap.averageSpeed,
         triggerRawValue: lap.triggerRawValue
      )
   }

   private static func encode(split: RideClimbSplit) -> RideBackupPayload.ClimbSplitRecord {
      RideBackupPayload.ClimbSplitRecord(
         index: split.index,
         startDate: split.startDate,
         endDate: split.endDate,
         startDistance: split.startDistance,
         endDistance: split.endDistance,
         distance: split.distance,
         duration: split.duration,
         elevationGain: split.elevationGain,
         averageSpeed: split.averageSpeed,
         averageGrade: split.averageGrade,
         categoryRawValue: split.categoryRawValue
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
