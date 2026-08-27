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

   // MARK: - Export Links

   /// Identifier of the HealthKit workout written for this ride.
   var healthKitWorkoutID: UUID?

   // MARK: - Samples

   @Relationship(deleteRule: .cascade, inverse: \RideSample.ride)
   var samples: [RideSample] = []

   // MARK: - Initialization

   init(startDate: Date, name: String = "") {
      self.startDate = startDate
      self.name = name
   }
}
