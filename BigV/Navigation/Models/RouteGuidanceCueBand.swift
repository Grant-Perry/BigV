//
//  RouteGuidanceCueBand.swift
//  BigV
//

import CoreLocation
import Foundation

/// The distance bands at which an upcoming turn is announced.
///
/// Declared widest first, which is also the order a rider crosses them. Each band
/// fires at most once per maneuver, so a turn is called four times at most: far
/// enough out to change lanes, again to commit, once more to slow, and at the
/// corner itself.
enum RouteGuidanceCueBand: String, Sendable, Equatable, CaseIterable {

   /// Roughly half a mile.
   case far

   /// Roughly five hundred feet.
   case near

   /// Roughly a hundred feet.
   case imminent

   /// At the corner.
   case now

   // MARK: - Thresholds

   /// Distance in meters at which this band fires for a slow rider.
   var baseDistance: CLLocationDistance {
      switch self {
         case .far: 805
         case .near: 152
         case .imminent: 30
         case .now: 8
      }
   }

   /// Seconds of warning this band is meant to buy.
   ///
   /// A rider at 25 mph covers 152 m in under fourteen seconds, which is not
   /// enough notice to move across a lane and slow down. Converting the band to a
   /// time gives them the same warning a slow rider gets in distance.
   var leadTime: TimeInterval {
      switch self {
         case .far: 60
         case .near: 20
         case .imminent: 6
         case .now: 0
      }
   }

   /// Where this band fires for a rider at `speed` meters/second.
   ///
   /// Speed can only ever push a band *further* out, never closer: `max` means a
   /// stopped rider still gets the full base distance and a fast one gets more.
   func triggerDistance(atSpeed speed: Double) -> CLLocationDistance {
      max(baseDistance, leadTime * max(0, speed))
   }

   // MARK: - Ordering

   /// Bands ordered widest first, so crossing several at once resolves to the
   /// tightest one rather than speaking all of them.
   static var widestFirst: [RouteGuidanceCueBand] { allCases }
}
