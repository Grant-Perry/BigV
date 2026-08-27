//
//  RouteGuidancePhase.swift
//  BigV
//

import Foundation

/// What the guidance layer is doing, for a rider glancing at a handlebar.
///
/// Separate from `RidePhase`: a ride can be recording with no route, and a route
/// can be drawn with guidance switched off.
enum RouteGuidancePhase: String, Sendable, Equatable {

   /// No route being followed, or the rider stopped guidance.
   case inactive

   /// Following the line, calling turns.
   case guiding

   /// Sustained deviation confirmed and no reroute in flight.
   case offRoute

   /// A replacement route has been asked for.
   case rerouting

   /// Repeated reroute attempts failed. Guidance stops asking and says so once.
   case rerouteUnavailable

   case arrived

   // MARK: - Derived

   var isActive: Bool { self != .inactive }

   /// Whether turn instructions are worth showing. Off-route instructions point
   /// at a line the rider is not on.
   var showsInstructions: Bool { self == .guiding }
}
