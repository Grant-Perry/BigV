//
//  RouteSearchFailure.swift
//  BigV
//

import Foundation

/// Why a destination search produced nothing usable.
enum RouteSearchFailure: String, Error, Sendable {

   /// The device has no route to Apple's search service.
   case offline

   /// The query is valid and the service answered, with nothing in it.
   case noResults

   /// The service answered with an error, or the chosen result carried no
   /// coordinate to ride to.
   case failed

   var message: String {
      switch self {
         case .offline: "No connection. Search needs the network."
         case .noResults: "No matches nearby."
         case .failed: "Search failed. Try again."
      }
   }
}
