//
//  RideTotalsTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

@MainActor
struct RideTotalsTests {

   // MARK: - Radar Totals From A Stored Ride

   @Test func aRideWithPassesFormatsItsRadarTotals() {
      let ride = Ride(startDate: Date(timeIntervalSince1970: 1_000_000))
      ride.vehicleCount = 27
      ride.closestPassDistance = 12       // meters -> 40 ft (rounded to fives)
      ride.maximumClosingSpeed = 9.5      // m/s -> 21.3 mph

      let totals = RideTotals(ride: ride, system: .imperial)

      #expect(totals.vehicleCount == "27")
      #expect(totals.closestPass == "40 ft")
      #expect(totals.maximumClosingSpeed == "21.3")
   }

   @Test func aRideWithPassesFormatsMetricRadarTotals() {
      let ride = Ride(startDate: Date(timeIntervalSince1970: 1_000_000))
      ride.vehicleCount = 27
      ride.closestPassDistance = 12       // whole meters
      ride.maximumClosingSpeed = 9.5      // m/s -> 34.2 km/h

      let totals = RideTotals(ride: ride, system: .metric)

      #expect(totals.closestPass == "12 m")
      #expect(totals.maximumClosingSpeed == "34.2")
   }

   @Test func aRideWithoutPassesHidesRadarTotals() {
      let ride = Ride(startDate: Date(timeIntervalSince1970: 1_000_000))

      let totals = RideTotals(ride: ride, system: .imperial)

      #expect(totals.vehicleCount == nil)
      #expect(totals.closestPass == nil)
      #expect(totals.maximumClosingSpeed == nil)
   }

   // MARK: - Radar Totals From Live State

   @Test func liveStateWithPassesFormatsItsRadarTotals() {
      var state = RideState()
      state.radar.vehiclePassCount = 4
      state.radar.closestPassDistanceMeters = 3
      state.radar.maximumPassClosingSpeedMetersPerSecond = 11.2

      let totals = RideTotals(state: state, system: .imperial)

      #expect(totals.vehicleCount == "4")
      #expect(totals.closestPass == "10 ft")
      #expect(totals.maximumClosingSpeed == "25.1")
   }

   @Test func liveStateWithoutPassesHidesRadarTotals() {
      let totals = RideTotals(state: RideState(), system: .imperial)

      #expect(totals.vehicleCount == nil)
      #expect(totals.closestPass == nil)
      #expect(totals.maximumClosingSpeed == nil)
   }
}
