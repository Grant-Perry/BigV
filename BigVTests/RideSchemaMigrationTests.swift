//
//  RideSchemaMigrationTests.swift
//  BigVTests
//

import Foundation
import SwiftData
import Testing
@testable import BigV

/// Proves a store written at V1 — the pre-radar shape that shipped — opens at
/// V2 through `RideMigrationPlan` with its data intact and radar defaults in
/// place. Runs against a real on-disk store: an in-memory container never
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

   // MARK: - Migration

   @Test func aV1StoreOpensAtV2WithDataIntactAndRadarDefaults() throws {
      let url = makeStoreURL()
      defer { removeStore(at: url) }

      let startDate = Date(timeIntervalSince1970: 1_000_000)
      try seedV1Store(at: url, startDate: startDate)

      let schema = Schema(versionedSchema: RideSchemaV2.self)
      let container = try ModelContainer(
         for: schema,
         migrationPlan: RideMigrationPlan.self,
         configurations: ModelConfiguration(schema: schema, url: url)
      )
      let context = ModelContext(container)

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
   }

   @Test func aMigratedStoreAcceptsRadarEvents() throws {
      let url = makeStoreURL()
      defer { removeStore(at: url) }

      let startDate = Date(timeIntervalSince1970: 1_000_000)
      try seedV1Store(at: url, startDate: startDate)

      let schema = Schema(versionedSchema: RideSchemaV2.self)
      let container = try ModelContainer(
         for: schema,
         migrationPlan: RideMigrationPlan.self,
         configurations: ModelConfiguration(schema: schema, url: url)
      )
      let context = ModelContext(container)

      let ride = try #require(try context.fetch(FetchDescriptor<Ride>()).first)
      let event = RideRadarEvent(
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

      let stored = try #require(try context.fetch(FetchDescriptor<RideRadarEvent>()).first)
      #expect(stored.peakTier == .high)
      #expect(stored.ride?.persistentModelID == ride.persistentModelID)
   }

   // MARK: - Plan Shape

   @Test func thePlanWalksV1ToV2() {
      #expect(RideMigrationPlan.schemas.count == 2)
      #expect(RideMigrationPlan.stages.count == 1)
      #expect(RideSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
      #expect(RideSchemaV2.versionIdentifier == Schema.Version(2, 0, 0))
   }
}
