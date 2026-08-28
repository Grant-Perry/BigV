//
//  RideFinalizerTests.swift
//  BigVTests
//

import Foundation
import SwiftData
import Testing
@testable import BigV

/// Covers the storage half of the pipeline. The Health half needs a real
/// `HKHealthStore` and an authorization prompt, so it stays a ride test.
@MainActor
struct RideFinalizerTests {

   // MARK: - Fixtures

   private func makeStorage() throws -> (RideStorageManager, ModelContext) {
      let container = try ModelContainer(
         for: Ride.self, RideSample.self,
         configurations: ModelConfiguration(isStoredInMemoryOnly: true)
      )
      let context = ModelContext(container)
      return (RideStorageManager(modelContext: context), context)
   }

   private func draft(index: Int, reference: Date) -> RideSampleDraft {
      RideSampleDraft(
         timestamp: reference.addingTimeInterval(Double(index)),
         latitude: 37.3349 + Double(index) * 0.0001,
         longitude: -122.0090,
         altitude: 100 + Double(index),
         speed: 8,
         distance: Double(index) * 10,
         grade: 1.5,
         course: 0
      )
   }

   private func finishedState(reference: Date, distance: Double) -> RideState {
      var state = RideState()
      state.phase = .finished
      state.startDate = reference
      state.endDate = reference.addingTimeInterval(600)
      state.elapsedTime = 600
      state.distance = distance
      return state
   }

   // MARK: - Capability

   @Test func aSessionWithoutHealthDoesNotAdvertiseAnExport() {
      #expect(RideFinalizer().exportsToHealth == false)
   }

   @Test func aSessionWithHealthAdvertisesAnExport() {
      let finalizer = RideFinalizer(rideHealthManager: RideHealthManager())

      #expect(finalizer.exportsToHealth)
   }

   // MARK: - Commit

   @Test func committingWithoutAStoreReturnsNil() {
      #expect(RideFinalizer().commit(RideState()) == nil)
   }

   @Test func committingClosesTheStoredRide() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)
      let finalizer = RideFinalizer(rideStorageManager: storage)

      storage.beginRide(startDate: reference)
      for index in 0..<10 {
         storage.append(draft(index: index, reference: reference), totals: RideState())
      }

      let commit = try #require(finalizer.commit(finishedState(reference: reference, distance: 5_000)))
      let ride = try #require(commit.ride)

      #expect(ride.distance == 5_000)
      #expect(ride.endDate == reference.addingTimeInterval(600))
      #expect(commit.hasStorageFailure == false)
      #expect(try context.fetch(FetchDescriptor<Ride>()).count == 1)
   }

   /// A store that rejects the ride still produced a commit — the distinction
   /// between "no store" and "store said no" is what the session acts on.
   @Test func committingAJunkRideReturnsACommitWithNoRide() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)
      let finalizer = RideFinalizer(rideStorageManager: storage)

      storage.beginRide(startDate: reference)
      storage.append(draft(index: 0, reference: reference), totals: RideState())

      let commit = try #require(finalizer.commit(finishedState(reference: reference, distance: 5)))

      #expect(commit.ride == nil)
      #expect(commit.hasStorageFailure == false)
      #expect(try context.fetch(FetchDescriptor<Ride>()).isEmpty)
   }

   // MARK: - Export

   @Test func exportingWithoutAHealthManagerReportsUnavailable() async throws {
      let (storage, _) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)
      let finalizer = RideFinalizer(rideStorageManager: storage)

      storage.beginRide(startDate: reference)
      storage.append(draft(index: 0, reference: reference), totals: RideState())
      let ride = try #require(storage.finalizeRide(with: finishedState(reference: reference, distance: 5_000)))

      let export = await finalizer.export(ride)

      #expect(export.status == .unavailable)
      #expect(export.hasStorageFailure == false)
      #expect(ride.healthKitWorkoutID == nil)
   }
}
