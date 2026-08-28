//
//  Ride.swift
//  BigV
//

import Foundation
import SwiftData

/// A completed or in-progress ride owned by BigV.
///
/// BigV is the system of record. HealthKit, GPX and FIT are export destinations.
@Model
final class Ride {

   // MARK: - Identity

   var startDate: Date = Date.distantPast
   var endDate: Date?
   var name: String = ""

   // MARK: - Totals

   /// Wall-clock ride duration in seconds, excluding paused time.
   var duration: TimeInterval = 0

   /// Seconds spent above the moving threshold.
   var movingTime: TimeInterval = 0

   /// Meters travelled.
   var distance: Double = 0

   /// Meters/second, averaged over moving time.
   var averageSpeed: Double = 0
   var maximumSpeed: Double = 0

   /// Meters climbed and descended.
   var elevationGain: Double = 0
   var elevationLoss: Double = 0

   // MARK: - Optional Totals

   var activeEnergy: Double?
   var averageHeartRate: Double?
   var averageCadence: Double?
   var averagePower: Double?

   // MARK: - Radar Totals

   /// Vehicles that passed while the ride was recording, from the rear radar.
   var vehicleCount: Int = 0

   /// Closest pass in meters. `nil` when the ride recorded no radar passes.
   var closestPassDistance: Double?

   /// Fastest closing speed in meters/second across every pass. `nil` when the
   /// ride recorded no radar passes.
   var maximumClosingSpeed: Double?

   // MARK: - Export Links

   /// Identifier of the HealthKit workout written for this ride.
   var healthKitWorkoutID: UUID?

   // MARK: - Samples

   @Relationship(deleteRule: .cascade, inverse: \RideSample.ride)
   var samples: [RideSample] = []

   // MARK: - Radar Events

   @Relationship(deleteRule: .cascade, inverse: \RideRadarEvent.ride)
   var radarEvents: [RideRadarEvent] = []

   // MARK: - Initialization

   init(startDate: Date, name: String = "") {
      self.startDate = startDate
      self.name = name
   }
}
