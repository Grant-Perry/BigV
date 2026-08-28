//
//  RideWatchHaptics.swift
//  BigV Watch App
//

import WatchKit

/// Wrist feedback for the two moments a rider needs to feel rather than look at.
///
/// Kept behind this seam so no view model imports WatchKit, and so the taps stay
/// rare: a cycling computer that buzzes on every tick is one the rider mutes.
@MainActor
enum RideWatchHaptics {

   /// The phone began a ride. Also the moment the sensor session comes up.
   static func playRideStart() {
      WKInterfaceDevice.current().play(.start)
   }

   /// The ride is over and the sensor session is down.
   static func playRideEnd() {
      WKInterfaceDevice.current().play(.stop)
   }

   // MARK: - Radar

   /// A vehicle entered the radar's board. Fired on the alert-pulse edge only,
   /// never per snapshot, so the wrist taps once per event like the phone does.
   static func playRadarApproach() {
      WKInterfaceDevice.current().play(.directionUp)
   }

   /// A tracked vehicle escalated to the high tier — the one tap that must
   /// read as urgent through a jersey sleeve.
   static func playRadarDanger() {
      WKInterfaceDevice.current().play(.notification)
   }
}
