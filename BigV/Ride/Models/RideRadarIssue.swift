//
//  RideRadarIssue.swift
//  BigV
//

import Foundation

/// A radar problem worth telling the rider about.
enum RideRadarIssue: String, Sendable, Equatable {

   case bluetoothOff
   case bluetoothUnauthorized

   /// A connect attempt ran out the clock: iOS never saw the radar advertise.
   /// Off, asleep, out of range, held by another phone, or a remembered
   /// identifier that stopped resolving — we cannot tell which, so we do not
   /// pretend to.
   case radarUnreachable

   case connectionLost

   /// Core Bluetooth reported an outright connect failure. Rare on iOS; the
   /// usual causes are the radar out of range mid-handshake or iOS being
   /// told to pair and the radar refusing it.
   case connectionFailed

   /// The link comes up and dies within a second, before a single GATT read
   /// lands. On a RearVue 820 that is the radar rejecting iPhone's pairing:
   /// a stale system bond ("peer removed pairing information") or the radar
   /// not in pairing mode. In-app Forget cannot clear the iOS-side bond.
   case pairingRejected

   var message: String {
      switch self {
         case .bluetoothOff: "Bluetooth is off. Turn it on to hear from your radar."
         case .bluetoothUnauthorized: "Bluetooth access denied. Enable it in Settings to use your radar."
         case .radarUnreachable: "Can’t reach the radar. Make sure it’s powered on and nearby."
         case .connectionLost: "Radar disconnected."
         case .connectionFailed: "The radar refused the connection. Turn it off and on, then Scan again."
         case .pairingRejected: "The radar connects, then drops: it isn’t in pairing mode. Turn it off, hold its button about 2 seconds until the status light flashes, then Scan again. Still dropping? Pair it once in the Garmin Varia™ app, then come back — BigVelo reuses that pairing."
      }
   }

   /// Wrist-sized.
   var watchMessage: String {
      switch self {
         case .bluetoothOff: "Bluetooth off on iPhone"
         case .bluetoothUnauthorized: "Allow Bluetooth on iPhone"
         case .radarUnreachable: "Radar not found"
         case .connectionLost: "Radar disconnected"
         case .connectionFailed: "Radar refused connection"
         case .pairingRejected: "Re-pair radar on iPhone"
      }
   }

   /// Whether the rider must change something before the radar can work.
   var requiresRiderAction: Bool {
      switch self {
         case .bluetoothOff, .bluetoothUnauthorized, .pairingRejected: true
         case .radarUnreachable, .connectionLost, .connectionFailed: false
      }
   }
}
