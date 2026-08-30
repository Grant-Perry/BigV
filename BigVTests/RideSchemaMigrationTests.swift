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
      let schema = Schema(versionedSchema: RideSchemaV3.self)
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

   // MARK: - Plan Shape

   @Test func thePlanWalksV1ToV3() {
      #expect(RideMigrationPlan.schemas.count == 3)
      #expect(RideMigrationPlan.stages.count == 2)
      #expect(RideSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
      #expect(RideSchemaV2.versionIdentifier == Schema.Version(2, 0, 0))
      #expect(RideSchemaV3.versionIdentifier == Schema.Version(3, 0, 0))
   }
}
