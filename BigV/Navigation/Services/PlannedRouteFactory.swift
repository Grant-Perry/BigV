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
enum PlannedRouteFactory {

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

      init(
         name: String = "",
         coordinates: [CLLocationCoordinate2D],
         distance: CLLocationDistance,
         expectedTravelTime: TimeInterval,
         advisories: [String] = [],
         maneuvers: [ManeuverDraft] = []
      ) {
         self.name = name
         self.coordinates = coordinates
         self.distance = distance
         self.expectedTravelTime = expectedTravelTime
         self.advisories = advisories
         self.maneuvers = maneuvers
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
      let coordinates = draft.coordinates.filter(RideRouteDownsampler.isUsable)
      guard coordinates.count > 1 else { return nil }

      return PlannedRoute(
         id: id,
         source: source,
         name: draft.name.trimmed,
         coordinates: coordinates,
         distance: distance(from: draft, geometry: coordinates),
         expectedTravelTime: max(0, draft.expectedTravelTime.finiteOrZero),
         maneuvers: maneuvers(from: draft.maneuvers),
         advisories: draft.advisories.compactMap(\.trimmedOrNil)
      )
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

private extension String {

   var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

   var trimmedOrNil: String? {
      let value = trimmed
      return value.isEmpty ? nil : value
   }
}

private extension Double {

   var finiteOrZero: Double { isFinite ? self : 0 }
}
