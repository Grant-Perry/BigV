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
}
