//
//  RouteRecentDestination.swift
//  BigV
//

import CoreLocation
import Foundation

/// A place the rider recently navigated to.
///
/// Only the destination is kept, not the line: a recent is "take me there
/// again", and Apple replans the ride from wherever the rider is now. A saved
/// line is what favorites are for.
nonisolated struct RouteRecentDestination: Identifiable, Codable, Sendable, Equatable {

   let id: UUID
   let visitedAt: Date
   let destination: RouteDestinationRecord

   /// Collapses the same place searched twice into one row, even when the
   /// geocoder hands back a coordinate a meter or two different.
   let key: String

   init(destination: RouteDestination, visitedAt: Date = .now) {
      id = UUID()
      self.visitedAt = visitedAt
      self.destination = RouteDestinationRecord(destination)
      key = Self.key(for: destination)
   }

   var routeDestination: RouteDestination { destination.routeDestination }

   var name: String { destination.name }

   var detail: String? { destination.detail }

   /// Name plus the coordinate to four places — about eleven meters, which is
   /// tighter than any two distinct addresses and looser than geocoder jitter.
   static func key(for destination: RouteDestination) -> String {
      let coordinate = destination.coordinate
      return [
         destination.name.lowercased(),
         String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
      ].joined(separator: "|")
   }
}
