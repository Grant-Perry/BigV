//
//  RideRadarEventStorageTests.swift
//  BigVTests
//

import Foundation
import SwiftData
import Testing
@testable import BigV

@MainActor
struct RideRadarEventStorageTests {

   // MARK: - Fixtures

   private func makeStorage() throws -> (RideStorageManager, ModelContext) {
      let container = try ModelContainer(
         for: Ride.self, RideSample.self, RideRadarEvent.self,
         configurations: ModelConfiguration(isStoredInMemoryOnly: true)
      )
      let context = ModelContext(container)
      return (RideStorageManager(modelContext: context), context)
   }

   private func pass(
      trackID: UInt8 = 3,
      minimumDistance: Double = 12,
      maximumClosingSpeed: Double = 9.5,
      peakTier: RideRadarThreatTier = .high,
      completedAt reference: Date
   ) -> RideRadarTracker.Pass {
      RideRadarTracker.Pass(
         trackID: trackID,
         minimumDistanceMeters: minimumDistance,
         maximumClosingSpeedMetersPerSecond: maximumClosingSpeed,
         peakTier: peakTier,
         firstSeenAt: reference.addingTimeInterval(-6),
         lastSeenAt: reference
      )
   }

   private func draft(reference: Date) -> RideSampleDraft {
      RideSampleDraft(
         timestamp: reference,
         latitude: 37.3349,
         longitude: -122.0090,
         altitude: 100,
         speed: 8,
         distance: 100,
         grade: 1.5,
         course: 0
      )
   }

   private func finishedState(startDate: Date) -> RideState {
      var state = RideState()
      state.phase = .finished
      state.startDate = startDate
      state.endDate = startDate.addingTimeInterval(1_800)
      state.elapsedTime = 1_800
      state.distance = 24_140
      return state
   }

   // MARK: - Round Trip

   @Test func aPassPersistsOneRowWithItsFields() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      storage.beginRide(startDate: reference)
      storage.appendRadarPass(
         pass(completedAt: reference.addingTimeInterval(30)),
         latitude: 37.3349,
         longitude: -122.0090
      )
      storage.flush()

      let event = try #require(try context.fetch(FetchDescriptor<RideRadarEvent>()).first)
      #expect(event.timestamp == reference.addingTimeInterval(30))
      #expect(event.trackID == 3)
      #expect(event.minimumDistance == 12)
      #expect(event.maximumClosingSpeed == 9.5)
      #expect(event.peakTier == .high)
      #expect(event.latitude == 37.3349)
      #expect(event.longitude == -122.0090)
      #expect(event.ride != nil)
      #expect(context.hasChanges == false)
   }

   @Test func aPassWithoutAFixStoresNoCoordinate() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      storage.beginRide(startDate: reference)
      storage.appendRadarPass(pass(completedAt: reference), latitude: nil, longitude: nil)
      storage.flush()

      let event = try #require(try context.fetch(FetchDescriptor<RideRadarEvent>()).first)
      #expect(event.latitude == nil)
      #expect(event.longitude == nil)
   }

   @Test func aPassWithoutAnActiveRideIsIgnored() throws {
      let (storage, context) = try makeStorage()

      storage.appendRadarPass(
         pass(completedAt: Date(timeIntervalSince1970: 1_000_000)),
         latitude: nil,
         longitude: nil
      )

      #expect(try context.fetch(FetchDescriptor<RideRadarEvent>()).isEmpty)
   }

   // MARK: - Ride Totals

   @Test func passesFoldIntoTheRidesTotals() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      storage.beginRide(startDate: reference)
      storage.appendRadarPass(
         pass(trackID: 1, minimumDistance: 20, maximumClosingSpeed: 6, peakTier: .approaching, completedAt: reference),
         latitude: nil, longitude: nil
      )
      storage.appendRadarPass(
         pass(trackID: 2, minimumDistance: 4, maximumClosingSpeed: 11, peakTier: .high, completedAt: reference.addingTimeInterval(60)),
         latitude: nil, longitude: nil
      )
      storage.appendRadarPass(
         pass(trackID: 3, minimumDistance: 15, maximumClosingSpeed: 7, peakTier: .approaching, completedAt: reference.addingTimeInterval(120)),
         latitude: nil, longitude: nil
      )
      storage.flush()

      let ride = try #require(try context.fetch(FetchDescriptor<Ride>()).first)
      #expect(ride.vehicleCount == 3)
      #expect(ride.closestPassDistance == 4)
      #expect(ride.maximumClosingSpeed == 11)
      #expect(ride.radarEvents.count == 3)
   }

   @Test func finalizingPreservesRadarTotals() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      storage.beginRide(startDate: reference)
      storage.append(draft(reference: reference), totals: RideState())
      storage.appendRadarPass(
         pass(minimumDistance: 8, maximumClosingSpeed: 10, completedAt: reference),
         latitude: nil, longitude: nil
      )

      let finalized = try #require(storage.finalizeRide(with: finishedState(startDate: reference)))

      #expect(finalized.vehicleCount == 1)
      #expect(finalized.closestPassDistance == 8)
      #expect(finalized.maximumClosingSpeed == 10)
      #expect(context.hasChanges == false)
   }

   @Test func aRideWithoutPassesKeepsNilRadarTotals() throws {
      let (storage, _) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      storage.beginRide(startDate: reference)
      storage.append(draft(reference: reference), totals: RideState())

      let finalized = try #require(storage.finalizeRide(with: finishedState(startDate: reference)))

      #expect(finalized.vehicleCount == 0)
      #expect(finalized.closestPassDistance == nil)
      #expect(finalized.maximumClosingSpeed == nil)
   }

   // MARK: - Deletion

   @Test func deletingARideCascadesToItsRadarEvents() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      storage.beginRide(startDate: reference)
      storage.append(draft(reference: reference), totals: RideState())
      storage.appendRadarPass(pass(completedAt: reference), latitude: nil, longitude: nil)
      let finalized = try #require(storage.finalizeRide(with: finishedState(startDate: reference)))

      storage.delete(finalized)

      #expect(try context.fetch(FetchDescriptor<Ride>()).isEmpty)
      #expect(try context.fetch(FetchDescriptor<RideRadarEvent>()).isEmpty)
   }

   @Test func discardingTheActiveRideRemovesItsRadarEvents() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      storage.beginRide(startDate: reference)
      storage.appendRadarPass(pass(completedAt: reference), latitude: nil, longitude: nil)

      storage.discardActiveRide(reason: .insufficientDistance)

      #expect(try context.fetch(FetchDescriptor<RideRadarEvent>()).isEmpty)
   }
}
