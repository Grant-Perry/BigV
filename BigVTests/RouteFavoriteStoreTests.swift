//
//  RouteFavoriteStoreTests.swift
//  BigVTests
//

import CoreLocation
import Foundation
import Testing
@testable import BigV

@MainActor
struct RouteFavoriteStoreTests {

   private func makeStore() -> (RouteFavoriteStore, UserDefaults) {
      let suiteName = "RouteFavoriteStoreTests.\(UUID().uuidString)"
      let defaults = UserDefaults(suiteName: suiteName)!
      defaults.removePersistentDomain(forName: suiteName)
      return (RouteFavoriteStore(defaults: defaults), defaults)
   }

   private func sampleRoute(name: String = "Sand Hill") -> PlannedRoute {
      PlannedRoute(
         id: UUID(),
         source: .gpx,
         name: name,
         coordinates: [
            CLLocationCoordinate2D(latitude: 37.42, longitude: -122.20),
            CLLocationCoordinate2D(latitude: 37.43, longitude: -122.19),
            CLLocationCoordinate2D(latitude: 37.44, longitude: -122.18)
         ],
         distance: 8_500,
         expectedTravelTime: 1_800,
         maneuvers: [],
         advisories: [],
         elevationProfile: [],
         climbs: []
      )
   }

   private func sampleDestination(name: String = "Trail End") -> RouteDestination {
      RouteDestination(
         name: name,
         coordinate: CLLocationCoordinate2D(latitude: 37.44, longitude: -122.18)
      )
   }

   @Test func toggleAddsThenRemoves() {
      let (store, _) = makeStore()
      let route = sampleRoute()
      let destination = sampleDestination()

      #expect(store.isEmpty)
      #expect(store.toggle(route: route, destination: destination) == true)
      #expect(store.favorites.count == 1)
      #expect(store.isFavorite(route: route, destination: destination))

      #expect(store.toggle(route: route, destination: destination) == false)
      #expect(store.isEmpty)
   }

   @Test func favoritesSurviveReload() {
      let (store, defaults) = makeStore()
      let route = sampleRoute(name: "Retained")
      let destination = sampleDestination(name: "Finish")

      _ = store.toggle(route: route, destination: destination)

      let reloaded = RouteFavoriteStore(defaults: defaults)
      #expect(reloaded.favorites.count == 1)
      #expect(reloaded.favorites.first?.label == "Retained")
      #expect(reloaded.isFavorite(route: route, destination: destination))
   }

   @Test func removeByID() {
      let (store, _) = makeStore()
      let route = sampleRoute()
      let destination = sampleDestination()
      _ = store.toggle(route: route, destination: destination)
      let id = store.favorites[0].id

      store.remove(id: id)

      #expect(store.isEmpty)
   }

   @Test func roundTripPreservesGeometry() throws {
      let route = sampleRoute(name: "Round Trip")
      let destination = sampleDestination()
      let favorite = SavedRouteFavorite(route: route, destination: destination)
      let data = try JSONEncoder().encode(favorite)
      let decoded = try JSONDecoder().decode(SavedRouteFavorite.self, from: data)

      #expect(decoded.plannedRoute.coordinates.count == route.coordinates.count)
      #expect(decoded.plannedRoute.name == "Round Trip")
      #expect(decoded.routeDestination.name == destination.name)
   }
}
