//
//  RouteDestination.swift
//  BigV
//

import CoreLocation
import Foundation

/// A place the rider has settled on, resolved down to a name and a coordinate.
///
/// Provider-neutral on purpose: the planner takes this, not a search result, so
/// a destination can equally come from a dropped pin or a saved favourite later.
nonisolated struct RouteDestination: Identifiable, Sendable {

   let id: UUID
   let name: String

   /// Street or context line, when the provider supplied one.
   let detail: String?

   let coordinate: CLLocationCoordinate2D

   init(
      id: UUID = UUID(),
      name: String,
      detail: String? = nil,
      coordinate: CLLocationCoordinate2D
   ) {
      self.id = id
      self.name = name
      self.detail = detail
      self.coordinate = coordinate
   }
}
