//
//  RideHealthManagerTests.swift
//  BigVTests
//

import Foundation
import HealthKit
import Testing
@testable import BigV

struct RideHealthManagerTests {

   // MARK: - Quantity Samples

   @Test func aPositiveDistanceProducesACyclingDistanceSample() {
      let start = Date(timeIntervalSince1970: 1_000_000)
      let end = start.addingTimeInterval(62)
      let samples = RideHealthManager.quantitySamples(
         distance: 64,
         activeEnergy: nil,
         from: start,
         to: end
      )

      #expect(samples.count == 1)
      #expect(samples[0].quantityType == HKQuantityType(.distanceCycling))
      #expect(samples[0].quantity.doubleValue(for: .meter()) == 64)
      #expect(samples[0].startDate == start)
      #expect(samples[0].endDate == end)
   }

   @Test func zeroDistanceProducesNoDistanceSample() {
      let start = Date(timeIntervalSince1970: 1_000_000)
      let samples = RideHealthManager.quantitySamples(
         distance: 0,
         activeEnergy: nil,
         from: start,
         to: start.addingTimeInterval(10)
      )

      #expect(samples.isEmpty)
   }

   @Test func positiveEnergyProducesAnEnergySample() {
      let start = Date(timeIntervalSince1970: 1_000_000)
      let samples = RideHealthManager.quantitySamples(
         distance: 0,
         activeEnergy: 12.5,
         from: start,
         to: start.addingTimeInterval(60)
      )

      #expect(samples.count == 1)
      #expect(samples[0].quantityType == HKQuantityType(.activeEnergyBurned))
      #expect(samples[0].quantity.doubleValue(for: .kilocalorie()) == 12.5)
   }

   @Test func missingOrZeroEnergyProducesNoEnergySample() {
      let start = Date(timeIntervalSince1970: 1_000_000)
      let end = start.addingTimeInterval(60)

      #expect(
         RideHealthManager.quantitySamples(
            distance: 0,
            activeEnergy: nil,
            from: start,
            to: end
         ).isEmpty
      )
      #expect(
         RideHealthManager.quantitySamples(
            distance: 0,
            activeEnergy: 0,
            from: start,
            to: end
         ).isEmpty
      )
   }
}
