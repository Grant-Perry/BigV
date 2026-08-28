//
//  RideWatchSensorEvent.swift
//  BigV Watch App
//

import Foundation

/// What the sensor session can report, with HealthKit's types left behind.
nonisolated enum RideWatchSensorEvent: Sendable {

   /// The session reached a terminal state — either because we ended it, or
   /// because watchOS did.
   case ended

   case failed(String)
}
