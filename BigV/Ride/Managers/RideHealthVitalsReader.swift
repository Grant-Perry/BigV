//
//  RideHealthVitalsReader.swift
//  BigV
//

import Foundation
import HealthKit

/// Reads a ride's vitals back out of Apple Health.
///
/// The Watch's workout session keeps the optical sensor sampling for the whole
/// ride and watchOS saves those beats to Health, so even a ride whose samples
/// carry no pulse usually has a full series waiting here. Read-only and
/// entirely optional: a denial or an empty window costs a chart, never a ride.
@MainActor
final class RideHealthVitalsReader {

   // MARK: - Vitals

   struct HeartBeat: Sendable, Equatable {
      let timestamp: Date
      let beatsPerMinute: Double
   }

   struct Vitals: Sendable, Equatable {
      let heartBeats: [HeartBeat]
      let activeEnergyKilocalories: Double?

      var isEmpty: Bool { heartBeats.isEmpty && activeEnergyKilocalories == nil }
   }

   // MARK: - Types

   /// Shared with `RideHealthManager` so the ride-start authorization sheet
   /// asks for reads and writes in one visit.
   static let readTypes: Set<HKObjectType> = [
      HKQuantityType(.heartRate),
      HKQuantityType(.activeEnergyBurned)
   ]

   // MARK: - Private Properties

   private let healthStore = HKHealthStore()

   private static let beatsPerMinuteUnit = HKUnit.count().unitDivided(by: .minute())

   // MARK: - Reading

   /// Everything Health knows about the ride's window. `nil` when Health is
   /// unavailable or the window holds nothing, so callers can hide the section
   /// rather than render an empty promise.
   func vitals(from start: Date, to end: Date) async -> Vitals? {
      guard HKHealthStore.isHealthDataAvailable(), end > start else { return nil }

      await requestAuthorizationIfNeeded()

      async let beats = heartBeats(from: start, to: end)
      async let energy = activeEnergy(from: start, to: end)

      let vitals = Vitals(heartBeats: await beats, activeEnergyKilocalories: await energy)
      return vitals.isEmpty ? nil : vitals
   }

   // MARK: - Authorization

   /// HealthKit never re-prompts once answered, so asking before every read is
   /// free — and it catches the rider who denied at ride time but has since
   /// changed their mind in Settings.
   private func requestAuthorizationIfNeeded() async {
      do {
         try await healthStore.requestAuthorization(toShare: [], read: Self.readTypes)
      } catch {
         DebugPrint(mode: .healthKit, "Vitals read authorization failed: \(error.localizedDescription)")
      }
   }

   // MARK: - Queries

   private func heartBeats(from start: Date, to end: Date) async -> [HeartBeat] {
      let interval = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
      let descriptor = HKSampleQueryDescriptor(
         predicates: [.quantitySample(type: HKQuantityType(.heartRate), predicate: interval)],
         sortDescriptors: [SortDescriptor(\.startDate)]
      )

      do {
         return try await descriptor.result(for: healthStore).map { sample in
            HeartBeat(
               timestamp: sample.startDate,
               beatsPerMinute: sample.quantity.doubleValue(for: Self.beatsPerMinuteUnit)
            )
         }
      } catch {
         DebugPrint(mode: .healthKit, "Heart rate read failed: \(error.localizedDescription)")
         return []
      }
   }

   private func activeEnergy(from start: Date, to end: Date) async -> Double? {
      let interval = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
      let descriptor = HKStatisticsQueryDescriptor(
         predicate: .quantitySample(
            type: HKQuantityType(.activeEnergyBurned),
            predicate: interval
         ),
         options: .cumulativeSum
      )

      do {
         let kilocalories = try await descriptor.result(for: healthStore)?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie())

         guard let kilocalories, kilocalories > 0 else { return nil }
         return kilocalories
      } catch {
         DebugPrint(mode: .healthKit, "Active energy read failed: \(error.localizedDescription)")
         return nil
      }
   }
}
