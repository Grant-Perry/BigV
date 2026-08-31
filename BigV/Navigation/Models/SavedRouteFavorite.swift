//
//  SavedRouteFavorite.swift
//  BigV
//

import CoreLocation
import Foundation

/// A route the rider saved from the planner for quick return.
///
/// Stores the full geometry — not just the destination — so a GPX import or
/// Apple route replays exactly as saved without another network hop.
nonisolated struct SavedRouteFavorite: Identifiable, Codable, Sendable, Equatable {

   let id: UUID
   let savedAt: Date
   let label: String
   let signature: String
   let route: PlannedRouteRecord
   let destination: RouteDestinationRecord

   init(route: PlannedRoute, destination: RouteDestination, label: String? = nil) {
      id = UUID()
      savedAt = .now
      self.label = label ?? Self.defaultLabel(route: route, destination: destination)
      signature = Self.signature(route: route, destination: destination)
      self.route = PlannedRouteRecord(route)
      self.destination = RouteDestinationRecord(destination)
   }

   var plannedRoute: PlannedRoute { route.plannedRoute }
   var routeDestination: RouteDestination { destination.routeDestination }

   func matches(route: PlannedRoute, destination: RouteDestination) -> Bool {
      signature == Self.signature(route: route, destination: destination)
   }

   static func signature(route: PlannedRoute, destination: RouteDestination) -> String {
      let end = destination.coordinate
      return [
         route.source.rawValue,
         route.name,
         String(format: "%.0f", route.distance),
         String(format: "%.5f,%.5f", end.latitude, end.longitude),
         String(route.coordinates.count)
      ].joined(separator: "|")
   }

   private static func defaultLabel(route: PlannedRoute, destination: RouteDestination) -> String {
      if !route.name.isEmpty { return route.name }
      if !destination.name.isEmpty { return destination.name }
      switch route.source {
         case .gpx: return "GPX Route"
         case .retrace: return "Back to Start"
         case .trailforks: return "Trail Route"
         case .appleMaps: return destination.name
      }
   }
}

// MARK: - Codable Records

nonisolated struct PlannedRouteRecord: Codable, Sendable, Equatable {

   let id: UUID
   let source: PlannedRouteSource
   let name: String
   let coordinates: [CoordinateRecord]
   let distance: Double
   let expectedTravelTime: TimeInterval
   let maneuvers: [PlannedRouteManeuverRecord]
   let advisories: [String]
   let elevationProfile: [RouteElevationSample]
   let climbs: [PlannedClimb]

   init(_ route: PlannedRoute) {
      id = route.id
      source = route.source
      name = route.name
      coordinates = route.coordinates.map(CoordinateRecord.init)
      distance = route.distance
      expectedTravelTime = route.expectedTravelTime
      maneuvers = route.maneuvers.map(PlannedRouteManeuverRecord.init)
      advisories = route.advisories
      elevationProfile = route.elevationProfile
      climbs = route.climbs
   }

   var plannedRoute: PlannedRoute {
      PlannedRoute(
         id: id,
         source: source,
         name: name,
         coordinates: coordinates.map(\.coordinate),
         distance: distance,
         expectedTravelTime: expectedTravelTime,
         maneuvers: maneuvers.map(\.maneuver),
         advisories: advisories,
         elevationProfile: elevationProfile,
         climbs: climbs
      )
   }
}

nonisolated struct RouteDestinationRecord: Codable, Sendable, Equatable {

   let id: UUID
   let name: String
   let detail: String?
   let coordinate: CoordinateRecord

   init(_ destination: RouteDestination) {
      id = destination.id
      name = destination.name
      detail = destination.detail
      coordinate = CoordinateRecord(destination.coordinate)
   }

   var routeDestination: RouteDestination {
      RouteDestination(
         id: id,
         name: name,
         detail: detail,
         coordinate: coordinate.coordinate
      )
   }
}

nonisolated struct PlannedRouteManeuverRecord: Codable, Sendable, Equatable {

   let id: Int
   let instruction: String
   let notice: String?
   let distance: Double
   let distanceFromStart: Double
   let coordinate: CoordinateRecord

   init(_ maneuver: PlannedRouteManeuver) {
      id = maneuver.id
      instruction = maneuver.instruction
      notice = maneuver.notice
      distance = maneuver.distance
      distanceFromStart = maneuver.distanceFromStart
      coordinate = CoordinateRecord(maneuver.coordinate)
   }

   var maneuver: PlannedRouteManeuver {
      PlannedRouteManeuver(
         id: id,
         instruction: instruction,
         notice: notice,
         distance: distance,
         distanceFromStart: distanceFromStart,
         coordinate: coordinate.coordinate
      )
   }
}

nonisolated struct CoordinateRecord: Codable, Sendable, Equatable {

   let latitude: Double
   let longitude: Double

   init(_ coordinate: CLLocationCoordinate2D) {
      latitude = coordinate.latitude
      longitude = coordinate.longitude
   }

   var coordinate: CLLocationCoordinate2D {
      CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
   }
}
