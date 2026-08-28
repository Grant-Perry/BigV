//
//  RoutePlanningFailure.swift
//  BigV
//

import Foundation

/// Why a cycling route could not be produced.
///
/// `noCyclingRoute` is kept apart from `failed` on purpose. Apple's cycling
/// coverage is not universal, so "there is no bike route here" is a real answer
/// about the world, not a malfunction — and the rider's next move is different in
/// each case.
enum RoutePlanningFailure: String, Error, Sendable {

   /// The service answered, and has no cycling route between these two points.
   case noCyclingRoute

   /// The device has no route to Apple's directions service.
   case offline

   /// The rider's position is unknown, so there is nothing to route from.
   case originUnavailable

   /// The service answered with an error, or with routes carrying no geometry.
   case failed

   var title: String {
      switch self {
         case .noCyclingRoute: "No Bike Route"
         case .offline: "Offline"
         case .originUnavailable: "Location Unknown"
         case .failed: "Routing Failed"
      }
   }

   var message: String {
      switch self {
         case .noCyclingRoute:
            "Apple Maps has no cycling directions between here and there. Cycling coverage is patchy outside cities."

         case .offline:
            "Planning a route needs the network. Reconnect and try again."

         case .originUnavailable:
            "BigVelo needs your location to plan a route from where you are."

         case .failed:
            "The routing service could not answer. Try again."
      }
   }
}
