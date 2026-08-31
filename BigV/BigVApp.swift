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
   @State private var rideUnitsSettings: RideUnitsSettings
   @State private var rideOnboardingSettings: RideOnboardingSettings
   @State private var bigVeloPlusStore: BigVeloPlusStore
   @State private var rideBackupViewModel: RideBackupViewModel
   @State private var rideMapViewModel: RideMapViewModel
   @State private var rideHistoryViewModel: RideHistoryViewModel
   @State private var rideRadarPairingViewModel: RideRadarPairingViewModel
   @State private var rideWeatherModel: RideWeatherModel
   @State private var rideClimbModel: RideClimbModel
   @State private var rideClimbSettings: RideClimbSettings
   @State private var rideLapSettings: RideLapSettings
   @State private var rideBackToStartModel: RideBackToStartModel

   /// The summary and history detail each get their own route view model so a
   /// finished ride's map can never be overwritten by browsing history.
   @State private var summaryRouteViewModel: RideRouteViewModel
   @State private var historyRouteViewModel: RideRouteViewModel

   /// The history detail screen's full report: charts, weather, traffic and
   /// the Apple Health read-back that enriches older rides.
   @State private var rideDetailViewModel: RideDetailViewModel
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

      // The radar is a road sensor on the same contract as the Watch: its
      // manager feeds the session, and only the pairing sheet talks to it
      // directly — for discovery, battery and firmware, never for ride state.
      let rideRadarManager = RideRadarManager()
      let rideRadarSettings = RideRadarSettings()
      let rideRadarAnnouncer = RideRadarAnnouncer(rideRadarSettings: rideRadarSettings)

      // One observable units store: the setup sheet writes it, the view models
      // read it, and the formatters' defaults read the same persisted key.
      let rideUnitsSettings = RideUnitsSettings()
      let rideClimbSettings = RideClimbSettings()
      let rideLapSettings = RideLapSettings()
      let routeFavoriteStore = RouteFavoriteStore()

      // Route planning and weather both need "where is the rider" while idle,
      // and neither may open a second `CLLocationManager` to get it.
      let currentLocationProbe = CurrentLocationProbe()

      // The Watch is a body sensor and a remote, so its manager is handed to the
      // session rather than to the view layer: heart rate and wrist commands go
      // through the one type allowed to publish a ride.
      let rideSessionManager = RideSessionManager(
         rideStorageManager: rideStorageManager,
         rideHealthManager: RideHealthManager(),
         rideRouteRecorder: rideRouteRecorder,
         routeGuidanceManager: routeGuidanceManager,
         rideWatchManager: RideWatchManager(),
         rideRadarManager: rideRadarManager,
         rideRadarAnnouncer: rideRadarAnnouncer,
         rideWeatherStamper: RideWeatherStamper(rideStorageManager: rideStorageManager),
         rideLapSettings: rideLapSettings
      )

      // Opened here, not per ride: START from the wrist has to reach an idle phone,
      // and radar alerts have to work while soft-pedalling before START.
      rideSessionManager.activateWatchLink()
      rideSessionManager.activateRadarLink()

      sharedModelContainer = modelContainer

      let rideViewModel = RideViewModel(
         rideSessionManager: rideSessionManager,
         rideRadarSettings: rideRadarSettings,
         rideUnitsSettings: rideUnitsSettings
      )
      _rideViewModel = State(initialValue: rideViewModel)
      _rideUnitsSettings = State(initialValue: rideUnitsSettings)
      let rideOnboardingSettings = RideOnboardingSettings()
      _rideOnboardingSettings = State(initialValue: rideOnboardingSettings)
      _bigVeloPlusStore = State(initialValue: BigVeloPlusStore())

      // Weather is owned here, not by the status row: a ride runs for hours,
      // and the chip must survive every dashboard rebuild without refetching.
      _rideWeatherModel = State(
         initialValue: RideWeatherModel(
            weatherService: RideWeatherService(),
            locationProbe: currentLocationProbe,
            unitsSettings: rideUnitsSettings
         )
      )
      _rideClimbSettings = State(initialValue: rideClimbSettings)
      _rideLapSettings = State(initialValue: rideLapSettings)

      // Climbs are owned here for the same reason weather is: the page, the
      // dashboard tile and the split recorder all read one model that outlives
      // any view.
      _rideClimbModel = State(
         initialValue: RideClimbModel(
            rideSessionManager: rideSessionManager,
            routeGuidanceManager: routeGuidanceManager,
            plannedRouteManager: plannedRouteManager,
            climbSettings: rideClimbSettings,
            unitsSettings: rideUnitsSettings
         )
      )
      // Back to Start gets its own route provider for the same reason guidance
      // does: `MKDirections` refuses two calculations at once.
      _rideBackToStartModel = State(
         initialValue: RideBackToStartModel(
            rideRouteRecorder: rideRouteRecorder,
            plannedRouteManager: plannedRouteManager,
            plannedRouteProvider: MapKitCyclingRoutePlanner()
         )
      )
      _rideRadarPairingViewModel = State(
         initialValue: RideRadarPairingViewModel(
            rideRadarManager: rideRadarManager,
            rideSessionManager: rideSessionManager,
            rideRadarSettings: rideRadarSettings
         )
      )
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
            currentLocationProbe: currentLocationProbe,
            plannedRouteManager: plannedRouteManager,
            routeFavoriteStore: routeFavoriteStore
         )
      )
      _routeGuidanceViewModel = State(
         initialValue: RouteGuidanceViewModel(routeGuidanceManager: routeGuidanceManager)
      )

      let rideHistoryViewModel = RideHistoryViewModel(rideStorageManager: rideStorageManager)
      _rideHistoryViewModel = State(initialValue: rideHistoryViewModel)

      // Backup needs the same storage and preference objects the rest of the
      // graph already owns — export/import never opens a second SwiftData stack.
      _rideBackupViewModel = State(
         initialValue: RideBackupViewModel(
            backupManager: RideBackupManager(
               rideStorageManager: rideStorageManager,
               unitsSettings: rideUnitsSettings,
               radarSettings: rideRadarSettings,
               onboardingSettings: rideOnboardingSettings
            ),
            isRideInProgress: {
               rideViewModel.isRecording
                  || rideViewModel.isPaused
                  || rideViewModel.isAcquiringGPS
            },
            onHistoryChanged: { rideHistoryViewModel.load() }
         )
      )
      _summaryRouteViewModel = State(
         initialValue: RideRouteViewModel(rideStorageManager: rideStorageManager)
      )
      _historyRouteViewModel = State(
         initialValue: RideRouteViewModel(rideStorageManager: rideStorageManager)
      )
      _rideDetailViewModel = State(
         initialValue: RideDetailViewModel(
            rideStorageManager: rideStorageManager,
            vitalsReader: RideHealthVitalsReader()
         )
      )
   }

   // MARK: - Scene

   var body: some Scene {
      WindowGroup {
         RideLaunchGate(
            plusStore: bigVeloPlusStore,
            onboardingSettings: rideOnboardingSettings
         ) {
            RideRootView(
               rideViewModel: rideViewModel,
               rideMapViewModel: rideMapViewModel,
               rideHistoryViewModel: rideHistoryViewModel,
               summaryRouteViewModel: summaryRouteViewModel,
               historyRouteViewModel: historyRouteViewModel,
               rideDetailViewModel: rideDetailViewModel,
               routePlannerViewModel: routePlannerViewModel,
               routeGuidanceViewModel: routeGuidanceViewModel,
               rideRadarPairingViewModel: rideRadarPairingViewModel,
               rideUnitsSettings: rideUnitsSettings,
               rideOnboardingSettings: rideOnboardingSettings,
               plusStore: bigVeloPlusStore,
               rideBackupViewModel: rideBackupViewModel,
               rideClimbSettings: rideClimbSettings,
               rideLapSettings: rideLapSettings
            )
         }
         .environment(rideWeatherModel)
         .environment(rideClimbModel)
         .environment(rideBackToStartModel)
         .task {
            await bigVeloPlusStore.loadProducts()
         }
      }
      .modelContainer(sharedModelContainer)
   }

   // MARK: - Store

   private static func makeModelContainer() -> ModelContainer {
      let schema = Schema(versionedSchema: RideSchemaV4.self)
      let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

      do {
         return try ModelContainer(
            for: schema,
            migrationPlan: RideMigrationPlan.self,
            configurations: [modelConfiguration]
         )
      } catch {
         fatalError("Could not create ModelContainer: \(error)")
      }
   }
}
