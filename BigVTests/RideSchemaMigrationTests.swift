//
//  RideSchemaMigrationTests.swift
//  BigVTests
//

import Foundation
import SwiftData
import Testing
@testable import BigV

/// Proves stores written at older schema versions open at the current one
/// through `RideMigrationPlan` with their data intact and new fields at their
/// defaults. Runs against a real on-disk store: an in-memory container never
/// exercises migration.
@MainActor
struct RideSchemaMigrationTests {

   // MARK: - Store Files

   private func makeStoreURL() -> URL {
      URL.temporaryDirectory.appending(component: "RideMigration-\(UUID().uuidString).store")
   }

   private func removeStore(at url: URL) {
      let fileManager = FileManager.default
      try? fileManager.removeItem(at: url)
      try? fileManager.removeItem(at: URL(filePath: url.path() + "-wal"))
      try? fileManager.removeItem(at: URL(filePath: url.path() + "-shm"))
   }

   private func openCurrent(at url: URL) throws -> ModelContext {
      let schema = Schema(versionedSchema: RideSchemaV4.self)
      let container = try ModelContainer(
         for: schema,
         migrationPlan: RideMigrationPlan.self,
         configurations: ModelConfiguration(schema: schema, url: url)
      )
      return ModelContext(container)
   }

   // MARK: - Seeding

   /// Writes a V1 store and lets the container deinit so the file closes.
   private func seedV1Store(at url: URL, startDate: Date) throws {
      let container = try ModelContainer(
         for: Schema(versionedSchema: RideSchemaV1.self),
         configurations: ModelConfiguration(schema: Schema(versionedSchema: RideSchemaV1.self), url: url)
      )
      let context = ModelContext(container)

      let ride = RideSchemaV1.Ride(startDate: startDate, name: "Before radar")
      ride.distance = 24_140
      ride.duration = 1_800
      ride.maximumSpeed = 19.4
      context.insert(ride)

      let sample = RideSchemaV1.RideSample(
         timestamp: startDate.addingTimeInterval(60),
         latitude: 37.3349,
         longitude: -122.0090,
         altitude: 100,
         speed: 8,
         distance: 480,
         grade: 1.5,
         course: 90
      )
      sample.ride = ride
      context.insert(sample)

      try context.save()
   }

   /// Writes a V2 store — radar era, pre-weather — and lets the file close.
   private func seedV2Store(at url: URL, startDate: Date) throws {
      let container = try ModelContainer(
         for: Schema(versionedSchema: RideSchemaV2.self),
         configurations: ModelConfiguration(schema: Schema(versionedSchema: RideSchemaV2.self), url: url)
      )
      let context = ModelContext(container)

      let ride = RideSchemaV2.Ride(startDate: startDate, name: "Before weather")
      ride.distance = 12_000
      ride.vehicleCount = 1
      ride.closestPassDistance = 6
      context.insert(ride)

      let event = RideSchemaV2.RideRadarEvent(
         timestamp: startDate.addingTimeInterval(300),
         trackID: 5,
         minimumDistance: 6,
         maximumClosingSpeed: 12,
         peakTier: .high,
         latitude: 37.3349,
         longitude: -122.0090
      )
      event.ride = ride
      context.insert(event)

      try context.save()
   }

   /// Writes a V3 store — weather era, pre-laps — and lets the file close.
   private func seedV3Store(at url: URL, startDate: Date) throws {
      let container = try ModelContainer(
         for: Schema(versionedSchema: RideSchemaV3.self),
         configurations: ModelConfiguration(schema: Schema(versionedSchema: RideSchemaV3.self), url: url)
      )
      let context = ModelContext(container)

      let ride = RideSchemaV3.Ride(startDate: startDate, name: "Before laps")
      ride.distance = 32_000
      ride.elevationGain = 410
      ride.weatherSymbolName = "cloud.sun.fill"
      ride.startTemperatureCelsius = 14
      context.insert(ride)

      try context.save()
   }

   // MARK: - Migration

   @Test func aV1StoreOpensAtCurrentWithDataIntactAndDefaults() throws {
      let url = makeStoreURL()
      defer { removeStore(at: url) }

      let startDate = Date(timeIntervalSince1970: 1_000_000)
      try seedV1Store(at: url, startDate: startDate)

      let context = try openCurrent(at: url)

      let ride = try #require(try context.fetch(FetchDescriptor<Ride>()).first)
      #expect(ride.startDate == startDate)
      #expect(ride.name == "Before radar")
      #expect(ride.distance == 24_140)
      #expect(ride.duration == 1_800)
      #expect(ride.maximumSpeed == 19.4)
      #expect(ride.samples.count == 1)
      #expect(ride.samples.first?.latitude == 37.3349)

      // The radar additions arrive at their defaults, not garbage.
      #expect(ride.vehicleCount == 0)
      #expect(ride.closestPassDistance == nil)
      #expect(ride.maximumClosingSpeed == nil)
      #expect(ride.radarEvents.isEmpty)
      #expect(try context.fetch(FetchDescriptor<RideRadarEvent>()).isEmpty)

      // So do the weather fields.
      #expect(ride.weatherSymbolName == nil)
      #expect(ride.startTemperatureCelsius == nil)
      #expect(ride.endTemperatureCelsius == nil)
   }

   @Test func aV2StoreOpensAtCurrentWithRadarIntactAndNoWeather() throws {
      let url = makeStoreURL()
      defer { removeStore(at: url) }

      let startDate = Date(timeIntervalSince1970: 1_000_000)
      try seedV2Store(at: url, startDate: startDate)

      let context = try openCurrent(at: url)

      let ride = try #require(try context.fetch(FetchDescriptor<Ride>()).first)
      #expect(ride.name == "Before weather")
      #expect(ride.distance == 12_000)
      #expect(ride.vehicleCount == 1)
      #expect(ride.closestPassDistance == 6)

      let event = try #require(ride.radarEvents.first)
      #expect(event.peakTier == .high)
      #expect(event.minimumDistance == 6)

      #expect(ride.weatherSymbolName == nil)
      #expect(ride.startTemperatureCelsius == nil)
      #expect(ride.endTemperatureCelsius == nil)
      #expect(ride.windSpeedKilometersPerHour == nil)
   }

   @Test func aMigratedStoreAcceptsWeather() throws {
      let url = makeStoreURL()
      defer { removeStore(at: url) }

      let startDate = Date(timeIntervalSince1970: 1_000_000)
      try seedV2Store(at: url, startDate: startDate)

      let context = try openCurrent(at: url)

      let ride = try #require(try context.fetch(FetchDescriptor<Ride>()).first)
      ride.weatherSymbolName = "sun.max.fill"
      ride.weatherConditionLabel = "Clear"
      ride.startTemperatureCelsius = 18
      ride.endTemperatureCelsius = 21
      try context.save()

      let stored = try #require(try context.fetch(FetchDescriptor<Ride>()).first)
      #expect(stored.weatherSymbolName == "sun.max.fill")
      #expect(stored.startTemperatureCelsius == 18)
      #expect(stored.endTemperatureCelsius == 21)
   }

   @Test func aV3StoreOpensAtCurrentWithNoLaps() throws {
      let url = makeStoreURL()
      defer { removeStore(at: url) }

      let startDate = Date(timeIntervalSince1970: 1_000_000)
      try seedV3Store(at: url, startDate: startDate)

      let context = try openCurrent(at: url)

      let ride = try #require(try context.fetch(FetchDescriptor<Ride>()).first)
      #expect(ride.name == "Before laps")
      #expect(ride.distance == 32_000)
      #expect(ride.elevationGain == 410)
      #expect(ride.weatherSymbolName == "cloud.sun.fill")
      #expect(ride.startTemperatureCelsius == 14)

      // The lap additions arrive at their defaults: a pre-lap ride simply
      // never lapped.
      #expect(ride.lapCount == 0)
      #expect(ride.climbSplitCount == 0)
      #expect(ride.laps.isEmpty)
      #expect(ride.climbSplits.isEmpty)
      #expect(try context.fetch(FetchDescriptor<RideLap>()).isEmpty)
      #expect(try context.fetch(FetchDescriptor<RideClimbSplit>()).isEmpty)
   }

   @Test func aMigratedStoreAcceptsLapsAndClimbSplits() throws {
      let url = makeStoreURL()
      defer { removeStore(at: url) }

      let startDate = Date(timeIntervalSince1970: 1_000_000)
      try seedV3Store(at: url, startDate: startDate)

      let context = try openCurrent(at: url)
      let ride = try #require(try context.fetch(FetchDescriptor<Ride>()).first)

      var tracker = RideLapTracker()
      tracker.begin(at: startDate)
      let cutLap = tracker.cut(distance: 5_000, elevationGain: 80, at: startDate.addingTimeInterval(900))
      let cut = try #require(cutLap)

      let lap = RideLap(lap: cut)
      lap.ride = ride
      context.insert(lap)
      ride.lapCount += 1

      let split = RideClimbSplit(
         index: 1,
         draft: RideClimbSplitDraft(
            startDate: startDate.addingTimeInterval(300),
            endDate: startDate.addingTimeInterval(720),
            startDistance: 2_000,
            endDistance: 3_400,
            elevationGain: 95,
            averageGrade: 6.8,
            category: .four
         )
      )
      split.ride = ride
      context.insert(split)
      ride.climbSplitCount += 1
      try context.save()

      let stored = try #require(try context.fetch(FetchDescriptor<Ride>()).first)
      #expect(stored.lapCount == 1)
      #expect(stored.laps.first?.distance == 5_000)
      #expect(stored.laps.first?.triggerRawValue == RideLapTracker.Trigger.manual.rawValue)
      #expect(stored.climbSplits.first?.category == .four)
      #expect(stored.climbSplits.first?.elevationGain == 95)
   }

   // MARK: - Plan Shape

   @Test func thePlanWalksV1ToV4() {
      #expect(RideMigrationPlan.schemas.count == 4)
      #expect(RideMigrationPlan.stages.count == 3)
      #expect(RideSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
      #expect(RideSchemaV2.versionIdentifier == Schema.Version(2, 0, 0))
      #expect(RideSchemaV3.versionIdentifier == Schema.Version(3, 0, 0))
      #expect(RideSchemaV4.versionIdentifier == Schema.Version(4, 0, 0))
   }
}
