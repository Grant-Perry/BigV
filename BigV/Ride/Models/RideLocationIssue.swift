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
   case reducedAccuracy

   /// GPS is delivering, but too loosely to trust position sample to sample.
   /// Speed and distance still show from what the engine can measure;
   /// climbing waits for the fix to tighten. Two words on purpose: it sits
   /// under the accuracy chip in a column the sensor chips squeeze.
   case weakSignal

   var message: String {
      switch self {
         case .authorizationDenied: "Location access denied. Enable it in Settings to record a ride."
         case .servicesDisabled: "Location Services are off for this device."
         case .temporarilyUnavailable: "No GPS signal."
         case .failed: "Location updates stopped unexpectedly."
         case .reducedAccuracy: "Turn on Precise Location in Settings."
         case .weakSignal: "Weak GPS"
      }
   }

   /// Wrist-sized. The Ultra's GPS is not in this loop — the phone is.
   var watchMessage: String {
      switch self {
         case .authorizationDenied: "Allow Location on iPhone"
         case .servicesDisabled: "Turn on Location Services"
         case .temporarilyUnavailable: "No phone GPS yet"
         case .failed: "Phone GPS stopped"
         case .reducedAccuracy: "Turn on Precise Location"
         case .weakSignal: "Weak phone GPS"
      }
   }

   /// Whether the rider must change something before recording can work.
   var requiresRiderAction: Bool {
      switch self {
         case .authorizationDenied, .servicesDisabled, .reducedAccuracy: true
         case .temporarilyUnavailable, .failed, .weakSignal: false
      }
   }
}
