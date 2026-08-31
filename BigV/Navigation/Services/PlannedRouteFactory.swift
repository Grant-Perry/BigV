//
//  PlannedRouteFactory.swift
//  BigV
//

import CoreLocation
import Foundation

/// Turns whatever a provider hands over into a `PlannedRoute`.
///
/// Providers reduce their own response to a `Draft` — a bag of primitives — and
/// this decides what is fit to ride: which coordinates are usable, which steps
/// are worth showing as instructions, and how far along the route each of those
/// instructions sits.
///
/// Deliberately free of MapKit and of any network type, so the whole conversion
/// rule is testable. `MKRoute` cannot be constructed by a test, so the MapKit
/// adapter is kept to extraction only and every judgement lives here.
nonisolated enum PlannedRouteFactory {

   // MARK: - Drafts

   /// One provider step, before it is judged.
   struct ManeuverDraft: Sendable {

      var instruction: String
      var notice: String?
      var distance: CLLocationDistance
      var coordinates: [CLLocationCoordinate2D]

      init(
         instruction: String,
         notice: String? = nil,
         distance: CLLocationDistance,
         coordinates: [CLLocationCoordinate2D]
      ) {
         self.instruction = instruction
         self.notice = notice
         self.distance = distance
         self.coordinates = coordinates
      }
   }

   /// One provider route, before it is judged.
   struct Draft: Sendable {

      var name: String
      var coordinates: [CLLocationCoordinate2D]
      var distance: CLLocationDistance
      var expectedTravelTime: TimeInterval
      var advisories: [String]
      var maneuvers: [ManeuverDraft]

      /// One altitude per coordinate, when the provider carries them — a GPX
      /// file's `<ele>` values. Empty means no altitudes, and the route waits
      /// on Open-Meteo enrichment instead. A count that disagrees with
      /// `coordinates` is treated as no altitudes: misaligned heights would
      /// put climbs on the wrong hills.
      var altitudes: [Double]

      init(
         name: String = "",
         coordinates: [CLLocationCoordinate2D],
         distance: CLLocationDistance,
         expectedTravelTime: TimeInterval,
         advisories: [String] = [],
         maneuvers: [ManeuverDraft] = [],
         altitudes: [Double] = []
      ) {
         self.name = name
         self.coordinates = coordinates
         self.distance = distance
         self.expectedTravelTime = expectedTravelTime
         self.advisories = advisories
         self.maneuvers = maneuvers
         self.altitudes = altitudes
      }
   }

   // MARK: - Conversion

   /// The route a draft describes, or `nil` when it describes nothing rideable.
   ///
   /// A route with no drawable geometry is worse than no route at all: it puts a
   /// destination pin on the map with no way to reach it.
   static func route(
      from draft: Draft,
      source: PlannedRouteSource,
      id: UUID = UUID()
   ) -> PlannedRoute? {
      let geometry = usableGeometry(from: draft)
      guard geometry.coordinates.count > 1 else { return nil }

      let total = distance(from: draft, geometry: geometry.coordinates)

      // Provider-carried altitudes make the profile here, with no network hop.
      // The empty case is Apple's, which waits on Open-Meteo enrichment.
      let profile = RouteElevationEnricher.profile(
         coordinates: geometry.coordinates,
         altitudes: geometry.altitudes,
         claimedDistance: total
      )

      return PlannedRoute(
         id: id,
         source: source,
         name: draft.name.trimmed,
         coordinates: geometry.coordinates,
         distance: total,
         expectedTravelTime: max(0, draft.expectedTravelTime.finiteOrZero),
         maneuvers: maneuvers(from: draft.maneuvers),
         advisories: draft.advisories.compactMap(\.trimmedOrNil),
         elevationProfile: profile,
         climbs: ClimbDetector.climbs(in: profile)
      )
   }

   // MARK: - Geometry

   /// Coordinates fit to draw, with their altitudes kept in lockstep.
   ///
   /// Filtering the two arrays together is the point: dropping a coordinate
   /// without its altitude would shift every height after it onto the wrong
   /// stretch of road.
   private static func usableGeometry(
      from draft: Draft
   ) -> (coordinates: [CLLocationCoordinate2D], altitudes: [Double]) {
      guard draft.altitudes.count == draft.coordinates.count, !draft.altitudes.isEmpty else {
         return (draft.coordinates.filter(RideRouteDownsampler.isUsable), [])
      }

      var coordinates: [CLLocationCoordinate2D] = []
      var altitudes: [Double] = []
      coordinates.reserveCapacity(draft.coordinates.count)
      altitudes.reserveCapacity(draft.coordinates.count)

      for (coordinate, altitude) in zip(draft.coordinates, draft.altitudes)
      where RideRouteDownsampler.isUsable(coordinate) {
         coordinates.append(coordinate)
         altitudes.append(altitude)
      }

      return (coordinates, altitudes)
   }

   // MARK: - Distance

   /// Trusts the provider's total and measures the geometry only when that total
   /// is missing or nonsense. Providers know about switchbacks and elevation that
   /// a flat sum of the drawn line does not.
   private static func distance(
      from draft: Draft,
      geometry: [CLLocationCoordinate2D]
   ) -> CLLocationDistance {
      let claimed = draft.distance
      guard claimed.isFinite, claimed > 0 else { return length(of: geometry) }
      return claimed
   }

   private static func length(of coordinates: [CLLocationCoordinate2D]) -> CLLocationDistance {
      zip(coordinates, coordinates.dropFirst()).reduce(0) { total, pair in
         total + RideRouteDownsampler.meters(from: pair.0, to: pair.1)
      }
   }

   // MARK: - Maneuvers

   /// Maps steps to instructions the rider can act on.
   ///
   /// Steps with nothing to say are dropped from the list but still counted
   /// toward the running offset: Apple emits an instruction-less step for the
   /// leg that merely gets you onto the route, and skipping its length would
   /// place every following turn short of where it really is.
   private static func maneuvers(from drafts: [ManeuverDraft]) -> [PlannedRouteManeuver] {
      var maneuvers: [PlannedRouteManeuver] = []
      maneuvers.reserveCapacity(drafts.count)

      var offset: CLLocationDistance = 0

      for draft in drafts {
         let stepLength = max(0, draft.distance.finiteOrZero)
         let instruction = draft.instruction.trimmed

         defer { offset += stepLength }

         guard !instruction.isEmpty,
               let coordinate = draft.coordinates.first(where: RideRouteDownsampler.isUsable)
         else { continue }

         maneuvers.append(
            PlannedRouteManeuver(
               id: maneuvers.count,
               instruction: instruction,
               notice: draft.notice?.trimmedOrNil,
               distance: stepLength,
               distanceFromStart: offset,
               coordinate: coordinate
            )
         )
      }

      return maneuvers
   }
}

// MARK: - Sanitizing

private nonisolated extension String {

   var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

   var trimmedOrNil: String? {
      let value = trimmed
      return value.isEmpty ? nil : value
   }
}

private nonisolated extension Double {

   var finiteOrZero: Double { isFinite ? self : 0 }
}
