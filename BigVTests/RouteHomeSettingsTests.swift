//
//  RouteHomeSettingsTests.swift
//  BigVTests
//

import CoreLocation
import Foundation
import Testing
@testable import BigV

@MainActor
struct RouteHomeSettingsTests {

   private func makeSettings() -> (RouteHomeSettings, UserDefaults) {
      let suiteName = "RouteHomeSettingsTests.\(UUID().uuidString)"
      let defaults = UserDefaults(suiteName: suiteName)!
      defaults.removePersistentDomain(forName: suiteName)
      return (RouteHomeSettings(defaults: defaults), defaults)
   }

   private let home = RouteDestination(
      name: "Home",
      detail: "60th St",
      coordinate: CLLocationCoordinate2D(latitude: 36.98, longitude: -76.42)
   )

   @Test func startsUnset() {
      let (settings, _) = makeSettings()

      #expect(!settings.hasHome)
      #expect(settings.homeLabel == nil)
   }

   @Test func homeSurvivesReload() {
      let (settings, defaults) = makeSettings()
      settings.home = home

      let reloaded = RouteHomeSettings(defaults: defaults)

      #expect(reloaded.hasHome)
      #expect(reloaded.home?.name == "Home")
      #expect(reloaded.home?.coordinate.latitude == 36.98)
   }

   @Test func theLabelPrefersTheAddressLine() {
      let (settings, _) = makeSettings()
      settings.home = home
      #expect(settings.homeLabel == "60th St")

      settings.home = RouteDestination(name: "Just a Name", coordinate: home.coordinate)
      #expect(settings.homeLabel == "Just a Name")
   }

   @Test func clearingRemovesItFromDisk() {
      let (settings, defaults) = makeSettings()
      settings.home = home

      settings.clearHome()

      #expect(!settings.hasHome)
      #expect(!RouteHomeSettings(defaults: defaults).hasHome)
   }
}
