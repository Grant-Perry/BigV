//
//  RideClimbModelTests.swift
//  BigVTests
//

import CoreLocation
import Foundation
import Testing
@testable import BigV

@Suite(.serialized)
@MainActor
struct RideClimbModelTests {

   private static let origin = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
   private static let reference = Date(timeIntervalSince1970: 1_000_000)

   private func point(east: Double, north: Double = 0) -> CLLocationCoordinate2D {
      RouteGuidanceTestGeography.coordinate(east: east, north: north, from: Self.origin)
   }

   private func location(east: Double, second: TimeInterval) -> CLLocation {
      CLLocation(
         coordinate: point(east: east),
         altitude: 100 + max(0, east - 200) * 0.05,
         horizontalAccuracy: 5,
         verticalAccuracy: 5,
         course: 90,
         courseAccuracy: 5,
         speed: 6,
         speedAccuracy: 1,
         timestamp: Self.reference.addingTimeInterval(second)
      )
   }

   @Test func summitClimbSplitIsRecordedWhenRouteIsClearedOnArrival() {
      let plannedRouteManager = PlannedRouteManager()
      let announcer = RouteGuidanceSpeechAnnouncer()
      announcer.isEnabled = false

      let guidanceManager = RouteGuidanceManager(
         plannedRouteManager: plannedRouteManager,
         announcer: announcer
      )
      guidanceManager.isVoiceEnabled = false

      let climbModel = RideClimbModel(
         rideSessionManager: nil,
         routeGuidanceManager: guidanceManager,
         plannedRouteManager: plannedRouteManager
      )

      // Route with a climb that ends at the end of the route (summit finish: 200m to 1000m)
      let coordinates = stride(from: 0.0, through: 1_000.0, by: 20.0).map { point(east: $0) }
      var samples: [RouteElevationSample] = []
      for step in 0...10 {
         let d = Double(step) * 100
         let alt = d < 200 ? 100.0 : 100.0 + (d - 200) * 0.05
         samples.append(RouteElevationSample(distanceAlongRoute: d, altitude: alt))
      }

      let climb = PlannedClimb(
         id: 1,
         startDistance: 200,
         endDistance: 1_000,
         ascent: 40,
         averageGrade: 5,
         category: .four
      )

      let route = PlannedRoute(
         id: UUID(),
         source: .gpx,
         name: "Summit Climb Route",
         coordinates: coordinates,
         distance: 1_000,
         expectedTravelTime: 300,
         maneuvers: [],
         advisories: [],
         elevationProfile: samples,
         climbs: [climb]
      )

      let destination = RouteDestination(name: "Mountain Summit", coordinate: coordinates.last!)
      plannedRouteManager.activate(route, to: destination)

      // Rider rides along the route: simulates location fixes and 1Hz climbModel refreshes
      var east = 0.0
      var second = 0.0
      while east <= 1_000.001 {
         var state = RideState()
         state.phase = .recording
         state.speed = 6
         state.course = 90
         state.distance = east
         state.hasGPSFix = true

         guidanceManager.follow(location(east: east, second: second), state: state)
         climbModel.refresh(state: state)

         if east == 300 {
            #expect(climbModel.progress.activeClimb?.id == 1)
            #expect(climbModel.lastCompletedSplit == nil)
         }

         east += 20
         second += 3
      }

      // Guidance arrival triggered and cleared the active route
      #expect(guidanceManager.phase == .arrived)
      #expect(plannedRouteManager.hasActiveRoute == false)

      // The summit climb split was preserved and recorded!
      let split = climbModel.lastCompletedSplit
      #expect(split != nil)
      #expect(split?.category == .four)
      #expect(split?.elevationGain == 40)
      #expect(split?.endDistance == 980)
   }
}
