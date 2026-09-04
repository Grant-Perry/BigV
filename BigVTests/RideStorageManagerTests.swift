//
//  RideStorageManagerTests.swift
//  BigVTests
//

import Foundation
import SwiftData
import Testing
@testable import BigV

@MainActor
struct RideStorageManagerTests {

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

   private func populatedState(
      startDate: Date,
      endDate: Date,
      phase: RidePhase = .finished
   ) -> RideState {
      var state = RideState()
      state.phase = phase
      state.startDate = startDate
      state.endDate = endDate
      state.elapsedTime = 1_800
      state.movingTime = 1_620
      state.distance = 24_140
      state.averageSpeed = 14.9
      state.maximumSpeed = 19.4
      state.elevationGain = 312
      state.elevationLoss = 288
      return state
   }

   // MARK: - Ride Creation

   @Test func beginRideInsertsAndPersistsARide() throws {
      let (storage, context) = try makeStorage()

      storage.beginRide(startDate: Date(timeIntervalSince1970: 1_000_000))

      let rides = try context.fetch(FetchDescriptor<Ride>())
      #expect(rides.count == 1)
      #expect(storage.hasFailure == false)
      #expect(context.hasChanges == false)
   }

   @Test func beginRideIgnoresASecondCallWhileRideIsActive() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      storage.beginRide(startDate: reference)
      storage.beginRide(startDate: reference.addingTimeInterval(60))

      #expect(try context.fetch(FetchDescriptor<Ride>()).count == 1)
   }

   // MARK: - Round Trip

   @Test func samplesRoundTripThroughTheStore() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      storage.beginRide(startDate: reference)

      var state = RideState()
      state.phase = .recording

      for index in 0..<25 {
         state.distance = Double(index) * 10
         storage.append(draft(index: index, reference: reference), totals: state)
      }
      storage.flush()

      let samples = try context.fetch(FetchDescriptor<RideSample>())
      #expect(samples.count == 25)
      #expect(context.hasChanges == false)

      let ride = try #require(try context.fetch(FetchDescriptor<Ride>()).first)
      #expect(ride.samples.count == 25)

      let ordered = ride.samples.sorted { $0.timestamp < $1.timestamp }
      #expect(ordered.first?.distance == 0)
      #expect(ordered.last?.distance == 240)
      #expect(ordered.last?.altitude == 124)
      #expect(ordered.allSatisfy { $0.ride?.persistentModelID == ride.persistentModelID })
   }

   @Test func appendWithoutAnActiveRideIsIgnored() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      storage.append(draft(index: 0, reference: reference), totals: RideState())

      #expect(try context.fetch(FetchDescriptor<RideSample>()).isEmpty)
   }

   // MARK: - Totals Mapping

   @Test func finalizeMapsTotalsFromRideState() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)
      let endDate = reference.addingTimeInterval(1_800)

      storage.beginRide(startDate: reference)
      storage.append(draft(index: 0, reference: reference), totals: RideState())

      let state = populatedState(startDate: reference, endDate: endDate)
      let finalized = try #require(storage.finalizeRide(with: state))

      #expect(finalized.endDate == endDate)
      #expect(finalized.duration == 1_800)
      #expect(finalized.movingTime == 1_620)
      #expect(finalized.distance == 24_140)
      #expect(finalized.averageSpeed == 14.9)
      #expect(finalized.maximumSpeed == 19.4)
      #expect(finalized.elevationGain == 312)
      #expect(finalized.elevationLoss == 288)
      #expect(finalized.healthKitWorkoutID == nil)
      #expect(context.hasChanges == false)
   }

   @Test func finalizeDiscardsARideThatNeverProducedASample() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      storage.beginRide(startDate: reference)
      let finalized = storage.finalizeRide(with: populatedState(
         startDate: reference,
         endDate: reference.addingTimeInterval(5)
      ))

      #expect(finalized == nil)
      #expect(try context.fetch(FetchDescriptor<Ride>()).isEmpty)
   }

   // MARK: - Junk Rides

   @Test func finalizeDiscardsARideThatRecordedSamplesButNeverMoved() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      storage.beginRide(startDate: reference)
      for index in 0..<59 {
         storage.append(draft(index: index, reference: reference), totals: RideState())
      }

      var state = populatedState(startDate: reference, endDate: reference.addingTimeInterval(59))
      state.distance = 0

      #expect(storage.finalizeRide(with: state) == nil)
      #expect(try context.fetch(FetchDescriptor<Ride>()).isEmpty)
      #expect(try context.fetch(FetchDescriptor<RideSample>()).isEmpty)
      #expect(storage.hasFailure == false)
      #expect(context.hasChanges == false)
   }

   @Test func finalizeDiscardsARideJustUnderTheDistanceThreshold() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      storage.beginRide(startDate: reference)
      storage.append(draft(index: 0, reference: reference), totals: RideState())

      var state = populatedState(startDate: reference, endDate: reference.addingTimeInterval(90))
      state.distance = RideRetentionPolicy.minimumMeaningfulDistance - 0.01

      #expect(storage.finalizeRide(with: state) == nil)
      #expect(try context.fetch(FetchDescriptor<Ride>()).isEmpty)
   }

   @Test func finalizeKeepsALegitimateShortRide() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      storage.beginRide(startDate: reference)
      for index in 0..<8 {
         storage.append(draft(index: index, reference: reference), totals: RideState())
      }

      var state = populatedState(startDate: reference, endDate: reference.addingTimeInterval(90))
      state.distance = RideRetentionPolicy.minimumMeaningfulDistance

      let finalized = try #require(storage.finalizeRide(with: state))

      #expect(finalized.distance == RideRetentionPolicy.minimumMeaningfulDistance)
      #expect(try context.fetch(FetchDescriptor<Ride>()).count == 1)
      #expect(try context.fetch(FetchDescriptor<RideSample>()).count == 8)
   }

   @Test func discardingTheActiveRideRemovesItAndItsSamples() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      storage.beginRide(startDate: reference)
      for index in 0..<15 {
         storage.append(draft(index: index, reference: reference), totals: RideState())
      }

      storage.discardActiveRide(reason: .insufficientDistance)

      #expect(try context.fetch(FetchDescriptor<Ride>()).isEmpty)
      #expect(try context.fetch(FetchDescriptor<RideSample>()).isEmpty)
      #expect(storage.hasFailure == false)
      #expect(context.hasChanges == false)
   }

   @Test func discardingLeavesAlreadyFinalizedRidesUntouched() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      storage.beginRide(startDate: reference)
      for index in 0..<12 {
         storage.append(draft(index: index, reference: reference), totals: RideState())
      }
      storage.finalizeRide(with: populatedState(
         startDate: reference,
         endDate: reference.addingTimeInterval(600)
      ))

      let junkStart = reference.addingTimeInterval(3_600)
      storage.beginRide(startDate: junkStart)
      storage.append(draft(index: 0, reference: junkStart), totals: RideState())
      storage.discardActiveRide(reason: .insufficientDistance)

      let rides = try context.fetch(FetchDescriptor<Ride>())
      #expect(rides.count == 1)
      #expect(rides.first?.startDate == reference)
      #expect(try context.fetch(FetchDescriptor<RideSample>()).count == 12)
   }

   @Test func discardingWithoutAnActiveRideIsIgnored() throws {
      let (storage, context) = try makeStorage()

      storage.discardActiveRide(reason: .noSamples)

      #expect(try context.fetch(FetchDescriptor<Ride>()).isEmpty)
      #expect(storage.hasFailure == false)
   }

   @Test func finalizeWithoutAnActiveRideReturnsNil() throws {
      let (storage, _) = try makeStorage()

      #expect(storage.finalizeRide(with: RideState()) == nil)
   }

   // MARK: - Export Links

   @Test func linkingAHealthKitWorkoutPersists() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)
      let identifier = UUID()

      storage.beginRide(startDate: reference)
      storage.append(draft(index: 0, reference: reference), totals: RideState())
      let finalized = try #require(storage.finalizeRide(with: populatedState(
         startDate: reference,
         endDate: reference.addingTimeInterval(60)
      )))

      storage.linkHealthKitWorkout(identifier, to: finalized)

      let stored = try #require(try context.fetch(FetchDescriptor<Ride>()).first)
      #expect(stored.healthKitWorkoutID == identifier)
      #expect(context.hasChanges == false)
   }

   // MARK: - History

   @Test func savedRidesAreNewestFirst() throws {
      let (storage, _) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      for offset in [0.0, 3_600.0, 7_200.0] {
         let startDate = reference.addingTimeInterval(offset)
         storage.beginRide(startDate: startDate)
         storage.append(draft(index: 0, reference: startDate), totals: RideState())
         storage.finalizeRide(with: populatedState(
            startDate: startDate,
            endDate: startDate.addingTimeInterval(600)
         ))
      }

      let rides = storage.savedRides()
      #expect(rides.count == 3)
      #expect(rides.map(\.startDate) == [
         reference.addingTimeInterval(7_200),
         reference.addingTimeInterval(3_600),
         reference
      ])
   }

   @Test func savedRidesExcludesActiveUnfinalizedRide() throws {
      let (storage, _) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      // Active recording that has not ended
      storage.beginRide(startDate: reference)
      storage.append(draft(index: 0, reference: reference), totals: RideState())

      #expect(storage.savedRides().isEmpty)

      // Once finalized, it appears in savedRides
      storage.finalizeRide(with: populatedState(
         startDate: reference,
         endDate: reference.addingTimeInterval(600)
      ))

      #expect(storage.savedRides().count == 1)
   }

   // MARK: - Deletion

   @Test func deletingActiveRideClearsActiveRideReference() throws {
      let (storage, _) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      storage.beginRide(startDate: reference)
      storage.append(draft(index: 0, reference: reference), totals: RideState())

      let activeRideContext = try #require(storage.activeRideChartSamples())
      #expect(activeRideContext.samples.count == 1)

      // Finding the active ride and deleting it
      let sample = try #require(activeRideContext.samples.first)
      let rideID = try #require(sample.ride?.persistentModelID)
      if let activeRide = storage.ride(with: rideID) {
         storage.delete(activeRide)
      }

      #expect(storage.activeRideChartSamples() == nil)
   }

   @Test func deletingARideCascadesToItsSamples() throws {
      let (storage, context) = try makeStorage()
      let reference = Date(timeIntervalSince1970: 1_000_000)

      storage.beginRide(startDate: reference)
      for index in 0..<12 {
         storage.append(draft(index: index, reference: reference), totals: RideState())
      }
      let finalized = try #require(storage.finalizeRide(with: populatedState(
         startDate: reference,
         endDate: reference.addingTimeInterval(600)
      )))

      #expect(try context.fetch(FetchDescriptor<RideSample>()).count == 12)

      storage.delete(finalized)

      #expect(try context.fetch(FetchDescriptor<Ride>()).isEmpty)
      #expect(try context.fetch(FetchDescriptor<RideSample>()).isEmpty)
      #expect(storage.hasFailure == false)
   }
}
