//
//  RouteRecentStoreTests.swift
//  BigVTests
//

import CoreLocation
import Foundation
import Testing
@testable import BigV

@MainActor
struct RouteRecentStoreTests {

   private func makeStore() -> (RouteRecentStore, UserDefaults) {
      let suiteName = "RouteRecentStoreTests.\(UUID().uuidString)"
      let defaults = UserDefaults(suiteName: suiteName)!
      defaults.removePersistentDomain(forName: suiteName)
      return (RouteRecentStore(defaults: defaults), defaults)
   }

   private func place(_ name: String, latitude: Double = 37.44, longitude: Double = -122.18) -> RouteDestination {
      RouteDestination(
         name: name,
         detail: "\(name) St",
         coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
      )
   }

   @Test func recordingPutsTheNewestFirst() {
      let (store, _) = makeStore()

      store.record(place("First"))
      store.record(place("Second", latitude: 37.5))

      #expect(store.recents.map(\.name) == ["Second", "First"])
   }

   @Test func theSamePlaceAgainMovesToTheTopInsteadOfDuplicating() {
      let (store, _) = makeStore()

      store.record(place("Home"))
      store.record(place("Work", latitude: 37.5))
      // Geocoder jitter well under the four-decimal key.
      store.record(place("Home", latitude: 37.440004, longitude: -122.180003))

      #expect(store.recents.count == 2)
      #expect(store.recents.first?.name == "Home")
   }

   @Test func theListIsCappedAtTheLimit() {
      let (store, _) = makeStore()

      for index in 0..<(RouteRecentStore.limit + 3) {
         store.record(place("Place \(index)", latitude: 37 + Double(index) * 0.01))
      }

      #expect(store.recents.count == RouteRecentStore.limit)
      #expect(store.recents.first?.name == "Place \(RouteRecentStore.limit + 2)")
      #expect(store.recents.last?.name == "Place 3")
   }

   @Test func recentsSurviveReload() {
      let (store, defaults) = makeStore()
      store.record(place("Retained"))

      let reloaded = RouteRecentStore(defaults: defaults)

      #expect(reloaded.recents.count == 1)
      #expect(reloaded.recents.first?.name == "Retained")
      #expect(reloaded.recents.first?.detail == "Retained St")
   }

   @Test func removeAndClear() {
      let (store, _) = makeStore()
      store.record(place("A"))
      store.record(place("B", latitude: 37.5))
      let id = store.recents[0].id

      store.remove(id: id)
      #expect(store.recents.map(\.name) == ["A"])

      store.clear()
      #expect(store.isEmpty)
   }
}
