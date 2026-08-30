//
//  RideWatchSensorEvent.swift
//  BigV Watch App
//

import Foundation

/// What the sensor session can report, with HealthKit's types left behind.
nonisolated enum RideWatchSensorEvent: Sendable {

   /// Sensors are warm. This is the only state `startActivity(with:)` may be
   /// called from, so it is reported rather than swallowed.
   case prepared

   case running

   /// Paused by us, or by watchOS pausing the workout on the rider's behalf.
   case paused

   /// The session reached a terminal state — either because we ended it, or
   /// because watchOS did.
   case ended

   case failed(String)
}
