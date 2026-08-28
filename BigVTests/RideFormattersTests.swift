//
//  RideFormattersTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

struct RideFormattersTests {

   // MARK: - Speed

   @Test func imperialSpeedConvertsToMilesPerHour() {
      // 10 m/s = 22.369 mph.
      #expect(RideFormatters.speed(10, system: .imperial) == "22.4")
   }

   @Test func metricSpeedConvertsToKilometersPerHour() {
      // 10 m/s = 36 km/h.
      #expect(RideFormatters.speed(10, system: .metric) == "36.0")
   }

   @Test func negativeSpeedClampsToZero() {
      #expect(RideFormatters.speed(-3, system: .imperial) == "0.0")
      #expect(RideFormatters.speed(-3, system: .metric) == "0.0")
   }

   // MARK: - Distance

   @Test func imperialDistanceConvertsToMiles() {
      // 1609.344 m is exactly one mile.
      #expect(RideFormatters.distance(1_609.344, system: .imperial) == "1.00")
   }

   @Test func metricDistanceConvertsToKilometers() {
      #expect(RideFormatters.distance(2_500, system: .metric) == "2.50")
   }

   // MARK: - Elevation

   @Test func imperialElevationConvertsToFeet() {
      // 100 m = 328.08 ft.
      #expect(RideFormatters.elevation(100, system: .imperial) == "328")
   }

   @Test func metricElevationStaysInMeters() {
      #expect(RideFormatters.elevation(100, system: .metric) == "100")
   }

   @Test func elevationGainAndLossCarryTheirSigns() {
      #expect(RideFormatters.elevationGain(100, system: .metric) == "+100")
      #expect(RideFormatters.elevationLoss(100, system: .metric) == "-100")
   }

   // MARK: - Radar Distance

   @Test func metricRadarDistanceReadsWholeMeters() {
      #expect(RideFormatters.radarDistance(82.4, system: .metric) == "82 m")
   }

   @Test func imperialRadarDistanceReadsFeetRoundedToFives() {
      // 40 m = 131.2 ft, rounded to the nearest 5 → 130 ft.
      #expect(RideFormatters.radarDistance(40, system: .imperial) == "130 ft")
   }

   @Test func radarDistanceNeverGoesNegative() {
      #expect(RideFormatters.radarDistance(-2, system: .metric) == "0 m")
      #expect(RideFormatters.radarDistance(-2, system: .imperial) == "0 ft")
   }

   // MARK: - Accuracy

   @Test func accuracySpeaksTheActiveSystem() {
      #expect(RideFormatters.accuracy(10, system: .metric) == "10 m")
      #expect(RideFormatters.accuracy(10, system: .imperial) == "33 ft")
   }

   // MARK: - Default System

   @Test func theDefaultSystemIsImperialWhenNothingIsStored() {
      let defaults = UserDefaults(suiteName: #function)!
      defaults.removePersistentDomain(forName: #function)
      #expect(RideUnitSystem.stored(in: defaults) == .imperial)
   }

   @Test func aStoredMetricChoiceIsHonored() {
      let defaults = UserDefaults(suiteName: #function)!
      defaults.removePersistentDomain(forName: #function)
      defaults.set(RideUnitSystem.metric.rawValue, forKey: RideUnitSystem.defaultsKey)
      #expect(RideUnitSystem.stored(in: defaults) == .metric)
      defaults.removePersistentDomain(forName: #function)
   }

   // MARK: - Unit Labels

   @Test func unitLabelsFollowTheSystem() {
      #expect(RideUnitSystem.imperial.speedUnit == "MPH")
      #expect(RideUnitSystem.imperial.distanceUnit == "MI")
      #expect(RideUnitSystem.imperial.elevationUnit == "FT")
      #expect(RideUnitSystem.metric.speedUnit == "KM/H")
      #expect(RideUnitSystem.metric.distanceUnit == "KM")
      #expect(RideUnitSystem.metric.elevationUnit == "M")
   }

   // MARK: - Cardinal

   @Test func anUnknownCourseHasNoCardinal() {
      #expect(RideFormatters.cardinal(-1) == nil)
   }

   @Test func dueNorthIsN() {
      #expect(RideFormatters.cardinal(0) == "N")
      #expect(RideFormatters.cardinal(359) == "N")
   }

   @Test func theFourOrdinalsLandOnTheirPoints() {
      #expect(RideFormatters.cardinal(90) == "E")
      #expect(RideFormatters.cardinal(180) == "S")
      #expect(RideFormatters.cardinal(270) == "W")
   }

   @Test func northeastIsTheHalfwayPoint() {
      #expect(RideFormatters.cardinal(45) == "NE")
   }

   // MARK: - Degrees

   @Test func anUnknownCourseHasNoDegreeReadout() {
      #expect(RideFormatters.headingDegrees(-1) == nil)
   }

   @Test func headingDegreesRoundToTheNearestWholeDegree() {
      #expect(RideFormatters.headingDegrees(47.4) == "47°")
      #expect(RideFormatters.headingDegrees(47.6) == "48°")
   }

   @Test func threeSixtyDegreesReadAsZero() {
      #expect(RideFormatters.headingDegrees(359.6) == "0°")
   }
}
