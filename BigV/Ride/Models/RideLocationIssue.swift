//
//  RideLocationIssue.swift
//  BigV
//

import Foundation

/// A location problem worth telling the rider about.
enum RideLocationIssue: String, Sendable, Equatable {

   case authorizationDenied
   case servicesDisabled
   case temporarilyUnavailable
   case failed

   var message: String {
      switch self {
         case .authorizationDenied: "Location access denied. Enable it in Settings to record a ride."
         case .servicesDisabled: "Location Services are off for this device."
         case .temporarilyUnavailable: "No GPS signal."
         case .failed: "Location updates stopped unexpectedly."
      }
   }

   /// Whether the rider must change something before recording can work.
   var requiresRiderAction: Bool {
      switch self {
         case .authorizationDenied, .servicesDisabled: true
         case .temporarilyUnavailable, .failed: false
      }
   }
}
