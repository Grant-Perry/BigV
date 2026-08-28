//
//  RideTotals.swift
//  BigV
//

import Foundation

/// Ride totals already converted and formatted for display.
///
/// The live summary reads them from `RideState` and a saved ride reads them from
/// its stored row, so the two screens can never drift in how a total is shown.
/// Carries its own unit labels so a tile never pairs a metric figure with an
/// imperial label.
struct RideTotals: Sendable, Equatable {

   let distance: String
   let rideTime: String
   let movingTime: String
   let averageSpeed: String
   let maximumSpeed: String
   let elevationGain: String
   let elevationLoss: String

   let speedUnit: String
   let distanceUnit: String
   let elevationUnit: String

   // MARK: - Radar Totals

   /// `nil` when the ride recorded no radar passes, so a radar-less ride shows
   /// exactly the grid it always did. Closest pass carries its own short-range
   /// unit ("42 ft" / "13 m") because radar distances never read in miles.
   let vehicleCount: String?
   let closestPass: String?
   let maximumClosingSpeed: String?

   // MARK: - Initialization

   private init(
      distance: Double,
      duration: TimeInterval,
      movingTime: TimeInterval,
      averageSpeed: Double,
      maximumSpeed: Double,
      elevationGain: Double,
      elevationLoss: Double,
      vehiclePasses: Int,
      closestPassMeters: Double?,
      maximumClosingMetersPerSecond: Double?,
      system: RideUnitSystem
   ) {
      self.distance = RideFormatters.distance(distance, system: system)
      self.rideTime = RideFormatters.duration(duration)
      self.movingTime = RideFormatters.duration(movingTime)
      self.averageSpeed = RideFormatters.speed(averageSpeed, system: system)
      self.maximumSpeed = RideFormatters.speed(maximumSpeed, system: system)
      self.elevationGain = RideFormatters.elevationGain(elevationGain, system: system)
      self.elevationLoss = RideFormatters.elevationLoss(elevationLoss, system: system)

      speedUnit = system.speedUnit
      distanceUnit = system.distanceUnit
      elevationUnit = system.elevationUnit

      vehicleCount = vehiclePasses > 0 ? "\(vehiclePasses)" : nil
      closestPass = vehiclePasses > 0
         ? closestPassMeters.map { RideFormatters.radarDistance($0, system: system) }
         : nil
      maximumClosingSpeed = vehiclePasses > 0
         ? maximumClosingMetersPerSecond.map { RideFormatters.speed($0, system: system) }
         : nil
   }

   init(state: RideState, system: RideUnitSystem = .current) {
      self.init(
         distance: state.distance,
         duration: state.elapsedTime,
         movingTime: state.movingTime,
         averageSpeed: state.averageSpeed,
         maximumSpeed: state.maximumSpeed,
         elevationGain: state.elevationGain,
         elevationLoss: state.elevationLoss,
         vehiclePasses: state.radar.vehiclePassCount,
         closestPassMeters: state.radar.closestPassDistanceMeters,
         maximumClosingMetersPerSecond: state.radar.maximumPassClosingSpeedMetersPerSecond,
         system: system
      )
   }

   init(ride: Ride, system: RideUnitSystem = .current) {
      self.init(
         distance: ride.distance,
         duration: ride.duration,
         movingTime: ride.movingTime,
         averageSpeed: ride.averageSpeed,
         maximumSpeed: ride.maximumSpeed,
         elevationGain: ride.elevationGain,
         elevationLoss: ride.elevationLoss,
         vehiclePasses: ride.vehicleCount,
         closestPassMeters: ride.closestPassDistance,
         maximumClosingMetersPerSecond: ride.maximumClosingSpeed,
         system: system
      )
   }
}
