//
//  RideState.swift
//  BigV
//

import Foundation

/// The single source of truth for everything happening during a ride.
///
/// Stored in SI units: meters, meters/second, seconds, degrees. Providers write
/// into this state, views read from it. Views never derive ride metrics.
struct RideState: Sendable, Equatable {

   // MARK: - Lifecycle

   var phase: RidePhase = .idle

   /// Set when the first usable GPS fix arrives, not when START is pressed.
   var startDate: Date?
   var endDate: Date?

   // MARK: - Time

   var elapsedTime: TimeInterval = 0
   var movingTime: TimeInterval = 0
   var stoppedTime: TimeInterval = 0

   // MARK: - Speed (meters/second)

   var speed: Double = 0
   var averageSpeed: Double = 0
   var maximumSpeed: Double = 0
   var isMoving: Bool = false

   // MARK: - Distance (meters)

   var distance: Double = 0

   // MARK: - Elevation (meters)

   var altitude: Double?
   var elevationGain: Double = 0
   var elevationLoss: Double = 0

   /// Current grade as a percentage.
   var grade: Double = 0

   /// Vertical speed in meters/hour — VAM. Signed; zero until the telemetry
   /// engine's altitude window has enough history.
   var verticalSpeed: Double = 0

   // MARK: - Orientation

   /// Course over ground in degrees. Negative means unknown.
   var course: Double = -1

   // MARK: - GPS Health

   var horizontalAccuracy: Double?
   var hasGPSFix: Bool = false
   var locationIssue: RideLocationIssue?

   // MARK: - Persistence And Export

   /// Set when a local save failed. The ride keeps recording either way.
   var hasStorageFailure: Bool = false

   var healthKitExport: RideHealthExportStatus = .idle

   // MARK: - Rear Radar

   /// Everything the Varia radar knows about the road behind.
   var radar = RideRadarSnapshot()

   // MARK: - Sensor Slots

   /// Populated once the Watch or a BLE strap is connected.
   var heartRate: Double?

   /// Crank RPM. Requires a BLE cadence sensor or power meter.
   var cadence: Double?

   /// Watts from a power meter.
   var power: Double?
}
