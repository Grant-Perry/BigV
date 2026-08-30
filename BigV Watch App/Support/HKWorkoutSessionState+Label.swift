//
//  HKWorkoutSessionState+Label.swift
//  BigV Watch App
//

import HealthKit

nonisolated extension HKWorkoutSessionState {

   /// A readable state for the log. `String(describing:)` on an `@objc` enum
   /// prints a raw value, which is useless in the one trace that matters.
   var label: String {
      switch self {
         case .notStarted: "notStarted"
         case .prepared: "prepared"
         case .running: "running"
         case .paused: "paused"
         case .stopped: "stopped"
         case .ended: "ended"
         @unknown default: "unknown(\(rawValue))"
      }
   }
}
