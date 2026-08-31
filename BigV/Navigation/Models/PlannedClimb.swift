//
//  PlannedClimb.swift
//  BigV
//

import CoreLocation
import Foundation

// MARK: - Category

/// Garmin's climb classification, scored as average grade (%) × length (m).
///
/// The Edge 1050 draws these thresholds and riders already speak the language,
/// so BigV adopts them verbatim rather than inventing a scale of its own.
nonisolated enum ClimbCategory: Int, Sendable, Equatable, Comparable, CaseIterable, Codable {

   case uncategorized
   case four
   case three
   case two
   case one
   case hors

   /// The category a score earns, or `nil` when the effort is too small to be
   /// called a climb at all.
   init?(score: Double) {
      switch score {
         case let value where value > 80_000: self = .hors
         case let value where value > 64_000: self = .one
         case let value where value > 32_000: self = .two
         case let value where value > 16_000: self = .three
         case let value where value > 8_000: self = .four
         case let value where value > 1_500: self = .uncategorized
         default: return nil
      }
   }

   /// The badge riders expect: "HC" for hors catégorie, numbered otherwise.
   var label: String {
      switch self {
         case .hors: "HC"
         case .one: "CAT 1"
         case .two: "CAT 2"
         case .three: "CAT 3"
         case .four: "CAT 4"
         case .uncategorized: "CLIMB"
      }
   }

   static func < (lhs: ClimbCategory, rhs: ClimbCategory) -> Bool {
      lhs.rawValue < rhs.rawValue
   }
}

// MARK: - Climb

/// One detected climb on a planned route, expressed in the route's own
/// distance space so live progress is a subtraction, never a search.
nonisolated struct PlannedClimb: Identifiable, Sendable, Equatable, Codable {

   /// Position along the route's climb list, first climb first. Stable for the
   /// life of the route, which is all the page and the splits need.
   let id: Int

   /// Meters from the route start to the base of the climb.
   let startDistance: CLLocationDistance

   /// Meters from the route start to the top.
   let endDistance: CLLocationDistance

   /// Meters gained base to top.
   let ascent: Double

   /// Average grade over the whole climb, as a percentage.
   let averageGrade: Double

   let category: ClimbCategory

   // MARK: - Derived

   var length: CLLocationDistance { endDistance - startDistance }

   /// Whether a rider at `distance` along the route is on this climb.
   func contains(_ distance: CLLocationDistance) -> Bool {
      distance >= startDistance && distance < endDistance
   }
}
