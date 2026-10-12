//
//  RideBackupManagerTests.swift
//  BigVTests
//

import CoreLocation
import Foundation
import SwiftData
import Testing
@testable import BigV

@MainActor
struct RideBackupManagerTests {

   private static let rideStart = Date(timeIntervalSince1970: 1_700_000_000)
   private static let rideDistance = 12_000.0
   private static let rideDuration: TimeInterval = 1_800

   // MARK: - Round trip

   @Test func backupRoundTripsRideChildrenAndExtendedPreferences() throws {
      let source = try makeWorld()
      defer { source.cleanup() }
      let destination = try makeWorld()
      defer { destination.cleanup() }

      try seedRide(in: source, latitude: 37.5, sampleCount: 1, name: "Dawn loop", withChildren: true)
      applyArchivedPreferences(source)
      let homeID = source.home.home?.id
      let recentKey = source.recents.recents.first?.key

      let exported = try source.backup.exportBackup()
      defer { try? FileManager.default.removeItem(at: exported.url) }

      let payload = try decode(exported.url)
      #expect(payload.formatVersion == RideBackupPayload.currentFormatVersion)
      #expect(payload.preferences.extended?.home != nil)
      #expect(payload.preferences.extended?.favorites.count == 1)
      #expect(payload.preferences.extended?.weatherPin?.label == "Bend")

      let result = try destination.backup.importBackup(from: exported.url, rideInProgress: false)
      #expect(result.addedRideCount == 1)
      #expect(result.updatedRideCount == 0)
      #expect(result.skippedRideCount == 0)

      let ride = try #require(destination.storage.savedRides().first)
      #expect(destination.storage.savedRides().count == 1)
      #expect(ride.name == "Dawn loop")
      #expect(ride.distance == Self.rideDistance)
      #expect(ride.duration == Self.rideDuration)
      #expect(ride.samples.count == 1)
      #expect(ride.samples.first?.latitude == 37.5)
      #expect(ride.samples.first?.heartRate == 140)
      #expect(ride.radarEvents.count == 1)
      #expect(ride.radarEvents.first?.trackID == 7)
      #expect(ride.radarEvents.first?.peakTier == .high)
      #expect(ride.laps.count == 1)
      #expect(ride.lapCount == 1)
      #expect(ride.laps.first?.distance == 5_000)
      #expect(ride.laps.first?.triggerRawValue == RideLapTracker.Trigger.auto.rawValue)
      #expect(ride.climbSplits.count == 1)
      #expect(ride.climbSplitCount == 1)
      #expect(ride.climbSplits.first?.elevationGain == 95)
      #expect(ride.climbSplits.first?.category == .four)
      #expect(ride.weatherSymbolName == "cloud.sun.fill")
      #expect(ride.weatherConditionLabel == "Partly Cloudy")
      #expect(ride.startTemperatureCelsius == 18)
      #expect(ride.startApparentTemperatureCelsius == 17)
      #expect(ride.windSpeedKilometersPerHour == 12)
      #expect(ride.endTemperatureCelsius == 21)

      #expect(destination.home.home?.id == homeID)
      #expect(destination.home.home?.name == "Home")
      #expect(destination.home.home?.detail == "12 Oak St")
      #expect(destination.home.home?.coordinate.latitude == 37.5)
      #expect(destination.home.home?.coordinate.longitude == -122.25)
      #expect(destination.favorites.favorites.count == 1)
      #expect(destination.favorites.favorites.first?.label == "Sand Hill")
      #expect(destination.favorites.favorites.first?.route.coordinates.count == 3)
      #expect(destination.favorites.favorites.first?.destination.name == "Trail End")
      #expect(destination.recents.recents.count == 1)
      #expect(destination.recents.recents.first?.key == recentKey)
      #expect(destination.recents.recents.first?.name == "Cafe")

      let pin = RideWeatherPlaceStore.pinnedPlace(in: destination.defaults)
      #expect(pin?.label == "Bend")
      #expect(pin?.latitude == 44)
      #expect(pin?.longitude == -121.5)
      #expect(pin?.timeZoneIdentifier == "America/Los_Angeles")
      #expect(destination.weather.place?.label == "Bend")
      #expect(destination.weather.place?.source == .pinned)
      #expect(destination.appearance.mode == .light)
      #expect(destination.laps.autoLapUnits == 10)
      #expect(destination.climbs.autoSwitchEnabled == false)
      #expect(destination.guidance.isVoiceEnabled == false)
      #expect(RouteFavoriteSectionPreferences.isExpanded(in: destination.defaults) == false)
      #expect(RouteRecentSectionPreferences.isExpanded(in: destination.defaults) == false)
   }

   @Test func oldBackupLeavesPlacesAndNewerSwitchesUntouched() throws {
      let destination = try makeWorld()
      defer { destination.cleanup() }
      applyArchivedPreferences(destination)

      let url = try writeOldBackup()
      defer { try? FileManager.default.removeItem(at: url) }

      let result = try destination.backup.importBackup(from: url, rideInProgress: false)
      #expect(result.addedRideCount == 1)
      #expect(result.updatedRideCount == 0)

      let ride = try #require(destination.storage.savedRides().first)
      #expect(ride.name == "Legacy")
      #expect(ride.laps.isEmpty)
      #expect(ride.climbSplits.isEmpty)
      #expect(ride.lapCount == 0)
      #expect(ride.climbSplitCount == 0)

      #expect(destination.home.home?.name == "Home")
      #expect(destination.favorites.favorites.count == 1)
      #expect(destination.favorites.favorites.first?.label == "Sand Hill")
      #expect(destination.recents.recents.first?.name == "Cafe")
      #expect(destination.appearance.mode == .light)
      #expect(destination.laps.autoLapUnits == 10)
      #expect(destination.climbs.autoSwitchEnabled == false)
      #expect(destination.guidance.isVoiceEnabled == false)
      #expect(RideWeatherPlaceStore.pinnedPlace(in: destination.defaults)?.label == "Bend")
      #expect(destination.weather.place?.label == "Bend")
      #expect(RouteFavoriteSectionPreferences.isExpanded(in: destination.defaults) == false)
      #expect(RouteRecentSectionPreferences.isExpanded(in: destination.defaults) == false)
   }

   @Test func presentContainerClearsHomeFavoritesAndWeatherPin() throws {
      let source = try makeWorld()
      defer { source.cleanup() }
      let destination = try makeWorld()
      defer { destination.cleanup() }

      applyArchivedPreferences(destination)

      let exported = try source.backup.exportBackup()
      defer { try? FileManager.default.removeItem(at: exported.url) }

      let result = try destination.backup.importBackup(from: exported.url, rideInProgress: false)
      #expect(result.addedRideCount == 0)
      #expect(result.updatedRideCount == 0)

      #expect(destination.home.home == nil)
      #expect(destination.favorites.favorites.isEmpty)
      #expect(destination.recents.recents.isEmpty)
      #expect(RideWeatherPlaceStore.pinnedPlace(in: destination.defaults) == nil)
      #expect(destination.weather.place == nil)
      #expect(destination.appearance.mode == .dark)
      #expect(destination.laps.autoLapUnits == 0)
      #expect(destination.climbs.autoSwitchEnabled == true)
      #expect(destination.guidance.isVoiceEnabled == true)
      #expect(RouteFavoriteSectionPreferences.isExpanded(in: destination.defaults) == true)
      #expect(RouteRecentSectionPreferences.isExpanded(in: destination.defaults) == true)
   }

   @Test func matchingRideFillsMissingChildrenWithoutDuplicatingSamples() throws {
      let source = try makeWorld()
      defer { source.cleanup() }
      let destination = try makeWorld()
      defer { destination.cleanup() }

      try seedRide(in: source, latitude: 38.25, sampleCount: 2, name: "Dawn loop", withChildren: true)
      try seedRide(in: destination, latitude: 37.25, sampleCount: 1, name: "Kept", withChildren: false)

      let exported = try source.backup.exportBackup()
      defer { try? FileManager.default.removeItem(at: exported.url) }

      let filled = try destination.backup.importBackup(from: exported.url, rideInProgress: false)
      #expect(filled.addedRideCount == 0)
      #expect(filled.updatedRideCount == 1)
      #expect(filled.skippedRideCount == 0)

      let rides = destination.storage.savedRides()
      let ride = try #require(rides.first)
      #expect(rides.count == 1)
      #expect(ride.name == "Kept")
      #expect(ride.distance == Self.rideDistance)
      #expect(ride.duration == Self.rideDuration)
      #expect(ride.vehicleCount == 0)
      #expect(ride.samples.count == 1)
      #expect(ride.samples.first?.latitude == 37.25)
      #expect(ride.radarEvents.count == 1)
      #expect(ride.laps.count == 1)
      #expect(ride.lapCount == 1)
      #expect(ride.climbSplits.count == 1)
      #expect(ride.climbSplitCount == 1)
      #expect(ride.weatherSymbolName == "cloud.sun.fill")
      #expect(ride.weatherConditionLabel == "Partly Cloudy")
      #expect(ride.startTemperatureCelsius == 18)
      #expect(ride.endTemperatureCelsius == 21)

      let again = try destination.backup.importBackup(from: exported.url, rideInProgress: false)
      #expect(again.addedRideCount == 0)
      #expect(again.updatedRideCount == 0)
      #expect(again.skippedRideCount == 1)
      #expect(destination.storage.savedRides().count == 1)
      #expect(destination.storage.savedRides().first?.samples.count == 1)
      #expect(destination.storage.savedRides().first?.laps.count == 1)
   }

   // MARK: - Fixtures

   private struct World {
      let suiteName: String
      let defaults: UserDefaults
      let container: ModelContainer
      let context: ModelContext
      let storage: RideStorageManager
      let home: RouteHomeSettings
      let favorites: RouteFavoriteStore
      let recents: RouteRecentStore
      let appearance: RideAppearanceSettings
      let laps: RideLapSettings
      let climbs: RideClimbSettings
      let guidance: RouteGuidanceManager
      let weather: RideWeatherModel
      let backup: RideBackupManager

      func cleanup() {
         defaults.removePersistentDomain(forName: suiteName)
      }
   }

   private func makeWorld() throws -> World {
      let suiteName = "RideBackupTests.\(UUID().uuidString)"
      let defaults = UserDefaults(suiteName: suiteName)!
      defaults.removePersistentDomain(forName: suiteName)

      let container = try ModelContainer(
         for: Ride.self, RideSample.self, RideRadarEvent.self, RideLap.self, RideClimbSplit.self,
         configurations: ModelConfiguration(isStoredInMemoryOnly: true)
      )
      let context = ModelContext(container)
      let storage = RideStorageManager(modelContext: context)
      let units = RideUnitsSettings(defaults: defaults)
      let home = RouteHomeSettings(defaults: defaults)
      let favorites = RouteFavoriteStore(defaults: defaults)
      let recents = RouteRecentStore(defaults: defaults)
      let appearance = RideAppearanceSettings(defaults: defaults)
      let laps = RideLapSettings(defaults: defaults)
      let climbs = RideClimbSettings(defaults: defaults)
      let guidance = RouteGuidanceManager(defaults: defaults)
      let weather = RideWeatherModel(
         weatherService: RideWeatherService(),
         locationProbe: CurrentLocationProbe(),
         unitsSettings: units
      )
      let backup = RideBackupManager(
         rideStorageManager: storage,
         unitsSettings: units,
         radarSettings: RideRadarSettings(defaults: defaults),
         onboardingSettings: RideOnboardingSettings(defaults: defaults),
         cockpitLayoutSettings: RideCockpitLayoutSettings(defaults: defaults),
         appearanceSettings: appearance,
         lapSettings: laps,
         climbSettings: climbs,
         routeHomeSettings: home,
         routeFavoriteStore: favorites,
         routeRecentStore: recents,
         routeGuidanceManager: guidance,
         weatherModel: weather,
         defaults: defaults
      )

      return World(
         suiteName: suiteName,
         defaults: defaults,
         container: container,
         context: context,
         storage: storage,
         home: home,
         favorites: favorites,
         recents: recents,
         appearance: appearance,
         laps: laps,
         climbs: climbs,
         guidance: guidance,
         weather: weather,
         backup: backup
      )
   }

   private func applyArchivedPreferences(_ world: World) {
      world.home.home = RouteDestination(
         name: "Home",
         detail: "12 Oak St",
         coordinate: CLLocationCoordinate2D(latitude: 37.5, longitude: -122.25)
      )
      _ = world.favorites.toggle(route: sampleRoute(), destination: sampleDestination())
      world.recents.record(
         RouteDestination(
            name: "Cafe",
            coordinate: CLLocationCoordinate2D(latitude: 37.25, longitude: -122.5)
         )
      )
      world.weather.restorePinnedPlace(
         .pinned(
            coordinate: CLLocationCoordinate2D(latitude: 44, longitude: -121.5),
            label: "Bend",
            timeZone: TimeZone(identifier: "America/Los_Angeles")
         ),
         defaults: world.defaults
      )
      world.appearance.mode = .light
      world.laps.autoLapUnits = 10
      world.climbs.autoSwitchEnabled = false
      world.guidance.isVoiceEnabled = false
      RouteFavoriteSectionPreferences.setExpanded(false, in: world.defaults)
      RouteRecentSectionPreferences.setExpanded(false, in: world.defaults)
   }

   @discardableResult
   private func seedRide(
      in world: World,
      latitude: Double,
      sampleCount: Int,
      name: String,
      withChildren: Bool
   ) throws -> Ride {
      let start = Self.rideStart
      world.storage.beginRide(startDate: start)

      var state = RideState()
      state.phase = .recording
      state.distance = Self.rideDistance
      state.elapsedTime = Self.rideDuration
      state.movingTime = 1_700
      state.averageSpeed = 6.6
      state.maximumSpeed = 9.1
      state.elevationGain = 120
      state.elevationLoss = 40

      for index in 0..<sampleCount {
         var draft = RideSampleDraft(
            timestamp: start.addingTimeInterval(Double(index)),
            latitude: latitude,
            longitude: -122.2,
            altitude: 100,
            speed: 6,
            distance: Double(index) * 100,
            grade: 1,
            course: 90
         )
         draft.heartRate = 140
         world.storage.append(draft, totals: state)
      }

      state.phase = .finished
      state.startDate = start
      state.endDate = start.addingTimeInterval(Self.rideDuration)
      let ride = try #require(world.storage.finalizeRide(with: state))
      ride.name = name

      if withChildren {
         ride.vehicleCount = 3
         ride.closestPassDistance = 1.4
         ride.maximumClosingSpeed = 8
         ride.weatherSymbolName = "cloud.sun.fill"
         ride.weatherConditionLabel = "Partly Cloudy"
         ride.startTemperatureCelsius = 18
         ride.startApparentTemperatureCelsius = 17
         ride.windSpeedKilometersPerHour = 12
         ride.endTemperatureCelsius = 21

         let event = RideRadarEvent(
            timestamp: start.addingTimeInterval(30),
            trackID: 7,
            minimumDistance: 1.4,
            maximumClosingSpeed: 8,
            peakTier: .high,
            latitude: latitude,
            longitude: -122.2
         )
         event.ride = ride
         world.context.insert(event)

         var tracker = RideLapTracker()
         tracker.begin(at: start)
         let cutLap = tracker.cut(
            distance: 5_000,
            elevationGain: 80,
            at: start.addingTimeInterval(900),
            elapsed: 900,
            trigger: .auto
         )
         let cut = try #require(cutLap)
         let lap = RideLap(lap: cut)
         lap.ride = ride
         world.context.insert(lap)
         ride.lapCount = 1

         let split = RideClimbSplit(
            index: 1,
            draft: RideClimbSplitDraft(
               startDate: start.addingTimeInterval(300),
               endDate: start.addingTimeInterval(720),
               startDistance: 2_000,
               endDistance: 3_400,
               elevationGain: 95,
               averageGrade: 6.8,
               category: .four
            )
         )
         split.ride = ride
         world.context.insert(split)
         ride.climbSplitCount = 1
      }

      try world.context.save()
      return ride
   }

   private func sampleRoute() -> PlannedRoute {
      PlannedRoute(
         id: UUID(),
         source: .gpx,
         name: "Sand Hill",
         coordinates: [
            CLLocationCoordinate2D(latitude: 37.25, longitude: -122.5),
            CLLocationCoordinate2D(latitude: 37.5, longitude: -122.25),
            CLLocationCoordinate2D(latitude: 37.75, longitude: -122)
         ],
         distance: 8_500,
         expectedTravelTime: 1_800,
         maneuvers: [],
         advisories: []
      )
   }

   private func sampleDestination() -> RouteDestination {
      RouteDestination(
         name: "Trail End",
         coordinate: CLLocationCoordinate2D(latitude: 37.75, longitude: -122)
      )
   }

   private func writeOldBackup() throws -> URL {
      let start = Date(timeIntervalSince1970: 1_600_000_000)
      let payload = RideBackupPayload(
         formatVersion: RideBackupPayload.currentFormatVersion,
         exportedAt: start,
         preferences: RideBackupPayload.Preferences(
            unitSystem: RideUnitSystem.imperial.rawValue,
            temperatureUnit: RideTemperatureUnit.fahrenheit.rawValue,
            hasCompletedSetup: false,
            hasCompletedOnboarding: false,
            radarEnabled: false,
            radarPlacement: RideRadarPlacement.trailing.rawValue,
            radarAlertHaptics: true,
            radarAlertAudio: true,
            radarToneStyle: RideRadarToneStyle.multi.rawValue,
            radarClearTone: true,
            radarOverlayEnabled: true,
            radarDisclaimerAcknowledged: false,
            cockpitDashboardTiles: nil,
            cockpitTrafficTiles: nil
         ),
         rides: [
            RideBackupPayload.RideRecord(
               startDate: start,
               endDate: start.addingTimeInterval(600),
               name: "Legacy",
               duration: 600,
               movingTime: 580,
               distance: 4_000,
               averageSpeed: 6,
               maximumSpeed: 8,
               elevationGain: 20,
               elevationLoss: 10,
               activeEnergy: nil,
               averageHeartRate: nil,
               averageCadence: nil,
               averagePower: nil,
               vehicleCount: 0,
               closestPassDistance: nil,
               maximumClosingSpeed: nil,
               weatherSymbolName: nil,
               weatherConditionLabel: nil,
               startTemperatureCelsius: nil,
               startApparentTemperatureCelsius: nil,
               windSpeedKilometersPerHour: nil,
               endTemperatureCelsius: nil,
               samples: [
                  RideBackupPayload.SampleRecord(
                     timestamp: start,
                     latitude: 37,
                     longitude: -122,
                     altitude: 10,
                     speed: 5,
                     distance: 0,
                     grade: 0,
                     course: 0,
                     heartRate: nil,
                     cadence: nil,
                     power: nil
                  )
               ],
               radarEvents: [],
               laps: nil,
               climbSplits: nil
            )
         ]
      )

      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(payload)
      let text = String(decoding: data, as: UTF8.self)
      #expect(!text.contains("\"extended\""))
      #expect(!text.contains("\"laps\""))
      #expect(!text.contains("\"climbSplits\""))

      let url = FileManager.default.temporaryDirectory
         .appendingPathComponent("BigVelo-old-\(UUID().uuidString).json")
      try data.write(to: url, options: .atomic)
      return url
   }

   private func decode(_ url: URL) throws -> RideBackupPayload {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      return try decoder.decode(RideBackupPayload.self, from: Data(contentsOf: url))
   }
}
