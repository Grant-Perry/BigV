//
//  RideCockpitLayoutSettingsTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

@MainActor
struct RideCockpitLayoutSettingsTests {

   private static func makeDefaults() -> UserDefaults {
      let suite = "RideCockpitLayoutSettingsTests.\(UUID().uuidString)"
      let defaults = UserDefaults(suiteName: suite)!
      defaults.removePersistentDomain(forName: suite)
      return defaults
   }

   private static let everything = Set(RideCockpitMetric.allCases)

   // MARK: - Defaults

   @Test func startsWithTheClassicDashboard() {
      let layout = RideCockpitLayoutSettings(defaults: Self.makeDefaults())

      #expect(layout.dashboardTiles.prefix(2) == [.distance, .rideTime])
      #expect(layout.trafficTiles == [.distance, .rideTime])
      #expect(!layout.dashboardTiles.contains(.averageSpeed))
   }

   // MARK: - Swap

   @Test func swappingTwoCardsTradesTheirSlots() {
      let layout = RideCockpitLayoutSettings(defaults: Self.makeDefaults())

      let changed = layout.apply(.altitude, for: .distance, on: .dashboard, available: Self.everything)

      #expect(changed)
      #expect(layout.dashboardTiles.firstIndex(of: .altitude) == 0)
      #expect(layout.dashboardTiles.firstIndex(of: .distance) == RideCockpitLayoutSettings.defaultDashboardTiles.firstIndex(of: .altitude))
      #expect(layout.dashboardTiles.count == RideCockpitLayoutSettings.defaultDashboardTiles.count)
   }

   @Test func trafficCardsOnlyTradePlaces() {
      let layout = RideCockpitLayoutSettings(defaults: Self.makeDefaults())

      let choices = layout.choices(for: .distance, on: .traffic, available: Self.everything)
      #expect(choices.swaps == [.rideTime])
      #expect(choices.replacements.isEmpty)

      layout.apply(.rideTime, for: .distance, on: .traffic, available: Self.everything)
      #expect(layout.trafficTiles == [.rideTime, .distance])
   }

   // MARK: - Replace

   @Test func replacingPutsANewMetricInTheSlot() {
      let layout = RideCockpitLayoutSettings(defaults: Self.makeDefaults())
      let slot = layout.dashboardTiles.firstIndex(of: .altitude)!

      let changed = layout.apply(.averageSpeed, for: .altitude, on: .dashboard, available: Self.everything)

      #expect(changed)
      #expect(layout.dashboardTiles[slot] == .averageSpeed)
      #expect(!layout.dashboardTiles.contains(.altitude))
   }

   @Test func protectedCardsCannotBeReplaced() {
      let layout = RideCockpitLayoutSettings(defaults: Self.makeDefaults())

      let choices = layout.choices(for: .rideTime, on: .dashboard, available: Self.everything)
      #expect(choices.replacements.isEmpty)
      #expect(!choices.swaps.isEmpty)

      let changed = layout.apply(.averageSpeed, for: .rideTime, on: .dashboard, available: Self.everything)
      #expect(!changed)
      #expect(layout.dashboardTiles.contains(.rideTime))
   }

   @Test func aMetricAlreadyOnScreenIsNeverOfferedAsAReplacement() {
      let layout = RideCockpitLayoutSettings(defaults: Self.makeDefaults())

      let choices = layout.choices(for: .grade, on: .dashboard, available: Self.everything)

      #expect(!choices.replacements.contains(.altitude))
      #expect(choices.swaps.contains(.altitude))
      #expect(Set(choices.swaps).isDisjoint(with: choices.replacements))
      #expect(!choices.swaps.contains(.grade))
   }

   // MARK: - Availability

   @Test func cardsWithoutDataAreNeitherSwapsNorReplacements() {
      let layout = RideCockpitLayoutSettings(defaults: Self.makeDefaults())
      let available = Self.everything.subtracting([.heartRate, .distanceToGo, .arrivalTime, .ascentRemaining])

      let choices = layout.choices(for: .grade, on: .dashboard, available: available)

      #expect(!choices.swaps.contains(.heartRate))
      #expect(!choices.replacements.contains(.heartRate))

      let changed = layout.apply(.heartRate, for: .grade, on: .dashboard, available: available)
      #expect(!changed)
   }

   // MARK: - Persistence

   @Test func layoutSurvivesARelaunch() {
      let defaults = Self.makeDefaults()

      let first = RideCockpitLayoutSettings(defaults: defaults)
      first.apply(.averageSpeed, for: .altitude, on: .dashboard, available: Self.everything)
      first.apply(.rideTime, for: .distance, on: .traffic, available: Self.everything)

      let second = RideCockpitLayoutSettings(defaults: defaults)

      #expect(second.dashboardTiles == first.dashboardTiles)
      #expect(second.trafficTiles == [.rideTime, .distance])
   }

   @Test func resetPutsEveryCardBack() {
      let layout = RideCockpitLayoutSettings(defaults: Self.makeDefaults())
      layout.apply(.averageSpeed, for: .altitude, on: .dashboard, available: Self.everything)

      layout.reset()

      #expect(layout.dashboardTiles == RideCockpitLayoutSettings.defaultDashboardTiles)
      #expect(layout.trafficTiles == RideCockpitLayoutSettings.defaultTrafficTiles)
   }

   @Test func restoreDropsUnknownNamesAndKeepsTheProtectedCards() {
      let layout = RideCockpitLayoutSettings(defaults: Self.makeDefaults())

      layout.restore(dashboard: ["grade", "nonsense", "grade", "altitude"], traffic: nil)

      #expect(layout.dashboardTiles.contains(.distance))
      #expect(layout.dashboardTiles.contains(.rideTime))
      #expect(layout.dashboardTiles.filter { $0 == .grade }.count == 1)
      #expect(!layout.dashboardTiles.isEmpty)
      #expect(layout.trafficTiles == RideCockpitLayoutSettings.defaultTrafficTiles)
   }
}

// MARK: - Pages

struct RidePageDeckTests {

   @Test func trafficSitsBetweenTheDashboardAndTheRadar() {
      let pages = RidePage.allCases
      #expect(pages.firstIndex(of: .traffic) == pages.firstIndex(of: .dashboard)! + 1)
      #expect(pages.firstIndex(of: .radar) == pages.firstIndex(of: .traffic)! + 1)
   }

   @Test func onlyTheRadarPagesNeedARadar() {
      #expect(RidePage.traffic.requiresRadar)
      #expect(RidePage.radar.requiresRadar)
      #expect(!RidePage.dashboard.requiresRadar)
      #expect(!RidePage.climb.requiresRadar)
      #expect(!RidePage.map.requiresRadar)
   }

   @Test func onlyALeftTapePutsTheRoadOnTheLeft() {
      #expect(RideRadarPlacement.leading.trafficRoadLeads)
      #expect(!RideRadarPlacement.trailing.trafficRoadLeads)
      #expect(!RideRadarPlacement.top.trafficRoadLeads)
      #expect(!RideRadarPlacement.bottom.trafficRoadLeads)
   }
}
