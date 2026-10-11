//
//  RideFixDiagnostics.swift
//  BigV
//

import CoreLocation
import Foundation

/// One log line per Core Location fix, for field tests.
///
/// Built only when `DebugMode.locationFiltering` is active — the call site
/// passes it through `DebugPrint`'s autoclosure — so it costs nothing on a
/// normal ride. Everything a "0.0 mph with the clock running" report needs
/// is on the line: what the fix claimed, how old it was, and what the engine
/// did with it.
///
/// ```
/// fix age 0.4s hAcc 65.0m vAcc 10.0m spd -1.00±-1.00 crs -1 → rejected(poorAccuracy) | speed 0.00 dist 0
/// fix age 0.3s hAcc 34.1m vAcc 18.2m spd 4.51±0.90 crs 182 → acceptedCoarse | speed 4.51 dist 5
/// fix age 0.2s hAcc 8.0m vAcc 6.0m spd 4.70±0.40 crs 181 → accepted | speed 4.58 dist 48
/// ```
nonisolated enum RideFixDiagnostics {

   static func line(
      for location: CLLocation,
      outcome: RideTelemetryEngine.Outcome,
      speed: Double,
      distance: Double,
      now: Date = .now
   ) -> String {
      let age = now.timeIntervalSince(location.timestamp)

      return "fix age \(format(age, 1))s"
         + " hAcc \(format(location.horizontalAccuracy, 1))m"
         + " vAcc \(format(location.verticalAccuracy, 1))m"
         + " spd \(format(location.speed, 2))±\(format(location.speedAccuracy, 2))"
         + " crs \(Int(location.course))"
         + " → \(describe(outcome))"
         + " | speed \(format(speed, 2)) dist \(Int(distance))"
   }

   // MARK: - Formatting

   private static func describe(_ outcome: RideTelemetryEngine.Outcome) -> String {
      switch outcome {
         case .acquiredFix: "acquiredFix"
         case .reseeded: "reseeded"
         case .accepted: "accepted"
         case .acceptedCoarse: "acceptedCoarse"
         case .rejected(let reason): "rejected(\(reason.rawValue))"
      }
   }

   private static func format(_ value: Double, _ places: Int) -> String {
      String(format: "%.\(places)f", value)
   }
}
