//
//  RideSample.swift
//  BigV
//

import Foundation
import SwiftData

/// One accepted telemetry sample within a ride.
///
/// Only samples that survived accuracy, staleness and jump filtering are stored,
/// so this series is safe to feed straight into a HealthKit workout route.
@Model
final class RideSample {

   var timestamp: Date = Date.distantPast

   // MARK: - Position

   var latitude: Double = 0
   var longitude: Double = 0
   var altitude: Double = 0

   // MARK: - Derived Telemetry

   /// Smoothed speed in meters/second.
   var speed: Double = 0

   /// Cumulative ride distance in meters at this sample.
   var distance: Double = 0

   /// Grade percentage at this sample.
   var grade: Double = 0

   /// Course over ground in degrees. Negative means unknown.
   var course: Double = -1

   // MARK: - Sensors

   var heartRate: Double?
   var cadence: Double?
   var power: Double?

   // MARK: - Relationship

   var ride: Ride?

   // MARK: - Initialization

   init(
      timestamp: Date,
      latitude: Double,
      longitude: Double,
      altitude: Double,
      speed: Double,
      distance: Double,
      grade: Double,
      course: Double
   ) {
      self.timestamp = timestamp
      self.latitude = latitude
      self.longitude = longitude
      self.altitude = altitude
      self.speed = speed
      self.distance = distance
      self.grade = grade
      self.course = course
   }
}
