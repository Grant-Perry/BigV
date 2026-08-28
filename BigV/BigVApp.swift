//
//  BigVApp.swift
//  BigV
//
//  Created by Gp. on 8/27/26.
//

import SwiftData
import SwiftUI

@main
struct BigVApp: App {

   // MARK: - Object Graph

   /// The app is the composition root: it owns the store and hands finished
   /// view models to the view layer, so no view ever wires managers together.
   private let sharedModelContainer: ModelContainer

   @State private var rideViewModel: RideViewModel
   @State private var rideMapViewModel: RideMapViewModel
   @State private var rideHistoryViewModel: RideHistoryViewModel

   /// The summary and history detail each get their own route view model so a
   /// finished ride's map can never be overwritten by browsing history.
   @State private var summaryRouteViewModel: RideRouteViewModel
   @State private var historyRouteViewModel: RideRouteViewModel
   @State private var routePlannerViewModel: RoutePlannerViewModel
   @State private var routeGuidanceViewModel: RouteGuidanceViewModel

   init() {
      let modelContainer = Self.makeModelContainer()
      let rideStorageManager = RideStorageManager(modelContext: modelContainer.mainContext)
      let rideRouteRecorder = RideRouteRecorder()

      // The planner writes the route and the map reads it, so both are handed the
      // same manager here rather than discovering each other.
      let plannedRouteManager = PlannedRouteManager()

      // Guidance gets its own route provider. Sharing the planner's would let a
      // reroute cancel a request the rider is waiting on, since `MKDirections`
      // refuses two calculations at once and each provider cancels on entry.
      let routeGuidanceManager = RouteGuidanceManager(
         plannedRouteManager: plannedRouteManager,
         plannedRouteProvider: MapKitCyclingRoutePlanner()
      )

      // The Watch is a body sensor and a remote, so its manager is handed to the
      // session rather than to the view layer: heart rate and wrist commands go
      // through the one type allowed to publish a ride.
      let rideSessionManager = RideSessionManager(
         rideStorageManager: rideStorageManager,
         rideHealthManager: RideHealthManager(),
         rideRouteRecorder: rideRouteRecorder,
         routeGuidanceManager: routeGuidanceManager,
         rideWatchManager: RideWatchManager()
      )

      // Opened here, not per ride: START from the wrist has to reach an idle phone.
      rideSessionManager.activateWatchLink()

      sharedModelContainer = modelContainer
      _rideViewModel = State(initialValue: RideViewModel(rideSessionManager: rideSessionManager))
      _rideMapViewModel = State(
         initialValue: RideMapViewModel(
            rideSessionManager: rideSessionManager,
            rideRouteRecorder: rideRouteRecorder,
            plannedRouteManager: plannedRouteManager
         )
      )
      _routePlannerViewModel = State(
         initialValue: RoutePlannerViewModel(
            routeSearchService: RouteSearchService(),
            plannedRouteProvider: MapKitCyclingRoutePlanner(),
            currentLocationProbe: CurrentLocationProbe(),
            plannedRouteManager: plannedRouteManager
         )
      )
      _routeGuidanceViewModel = State(
         initialValue: RouteGuidanceViewModel(routeGuidanceManager: routeGuidanceManager)
      )
      _rideHistoryViewModel = State(
         initialValue: RideHistoryViewModel(rideStorageManager: rideStorageManager)
      )
      _summaryRouteViewModel = State(
         initialValue: RideRouteViewModel(rideStorageManager: rideStorageManager)
      )
      _historyRouteViewModel = State(
         initialValue: RideRouteViewModel(rideStorageManager: rideStorageManager)
      )
   }

   // MARK: - Scene

   var body: some Scene {
      WindowGroup {
         RideRootView(
            rideViewModel: rideViewModel,
            rideMapViewModel: rideMapViewModel,
            rideHistoryViewModel: rideHistoryViewModel,
            summaryRouteViewModel: summaryRouteViewModel,
            historyRouteViewModel: historyRouteViewModel,
            routePlannerViewModel: routePlannerViewModel,
            routeGuidanceViewModel: routeGuidanceViewModel
         )
      }
      .modelContainer(sharedModelContainer)
   }

   // MARK: - Store

   private static func makeModelContainer() -> ModelContainer {
      let schema = Schema([
         Ride.self,
         RideSample.self
      ])
      let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

      do {
         return try ModelContainer(for: schema, configurations: [modelConfiguration])
      } catch {
         fatalError("Could not create ModelContainer: \(error)")
      }
   }
}
