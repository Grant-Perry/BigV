//
//  RideRadarIssue.swift
//  BigV
//

import Foundation

/// A radar problem worth telling the rider about.
enum RideRadarIssue: String, Sendable, Equatable {

   case bluetoothOff
   case bluetoothUnauthorized

   /// The radar serves one BLE connection at a time. If the Garmin Varia app
   /// (or any other) holds it, BigVelo cannot connect until it lets go. An
   /// Edge on ANT+ is fine and can run alongside.
   case radarBusy

   case connectionLost
   case connectionFailed

   var message: String {
      switch self {
         case .bluetoothOff: "Bluetooth is off. Turn it on to hear from your radar."
         case .bluetoothUnauthorized: "Bluetooth access denied. Enable it in Settings to use your radar."
         case .radarBusy: "Another app is using the radar. Close the Garmin Varia™ app (or any other radar app), then try again. An Edge on ANT+ is fine."
         case .connectionLost: "Radar disconnected."
         case .connectionFailed: "Could not connect. Hold the radar’s button until it blinks purple (pairing), then Scan again."
      }
   }

   /// Wrist-sized.
   var watchMessage: String {
      switch self {
         case .bluetoothOff: "Bluetooth off on iPhone"
         case .bluetoothUnauthorized: "Allow Bluetooth on iPhone"
         case .radarBusy: "Radar in use by another app"
         case .connectionLost: "Radar disconnected"
         case .connectionFailed: "Radar unreachable"
      }
   }

   /// Whether the rider must change something before the radar can work.
   var requiresRiderAction: Bool {
      switch self {
         case .bluetoothOff, .bluetoothUnauthorized, .radarBusy: true
         case .connectionLost, .connectionFailed: false
      }
   }
}
