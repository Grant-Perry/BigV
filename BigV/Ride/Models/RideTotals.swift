//
//  RideTotals.swift
//  BigV
//

import Foundation

/// Ride totals already converted and formatted for display.
///
/// The live summary reads them from `RideState` and a saved ride reads them from
/// its stored row, so the two screens can never drift in how a total is shown.
struct RideTotals: Sendable, Equatable {

   let distance: String
   let rideTime: String
   let movingTime: String
   let averageSpeed: String
   let maximumSpeed: String
   let elevationGain: String
   let elevationLoss: String

   // MARK: - Initialization

   private init(
      distance: Double,
      duration: TimeInterval,
      movingTime: TimeInterval,
      averageSpeed: Double,
      maximumSpeed: Double,
      elevationGain: Double,
      elevationLoss: Double
   ) {
      self.distance = RideFormatters.distance(distance)
      self.rideTime = RideFormatters.duration(duration)
      self.movingTime = RideFormatters.duration(movingTime)
      self.averageSpeed = RideFormatters.speed(averageSpeed)
      self.maximumSpeed = RideFormatters.speed(maximumSpeed)
      self.elevationGain = RideFormatters.elevationGain(elevationGain)
      self.elevationLoss = RideFormatters.elevationLoss(elevationLoss)
   }

   init(state: RideState) {
      self.init(
         distance: state.distance,
         duration: state.elapsedTime,
         movingTime: state.movingTime,
         averageSpeed: state.averageSpeed,
         maximumSpeed: state.maximumSpeed,
         elevationGain: state.elevationGain,
         elevationLoss: state.elevationLoss
      )
   }

   init(ride: Ride) {
      self.init(
         distance: ride.distance,
         duration: ride.duration,
         movingTime: ride.movingTime,
         averageSpeed: ride.averageSpeed,
         maximumSpeed: ride.maximumSpeed,
         elevationGain: ride.elevationGain,
         elevationLoss: ride.elevationLoss
      )
   }
}
