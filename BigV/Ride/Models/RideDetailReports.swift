//
//  RideDetailReports.swift
//  BigV
//

import Foundation

// MARK: - Chart Point

/// One point on a detail chart, already converted to display units so the
/// chart layer never touches SI values or the unit preference.
struct RideChartPoint: Sendable, Equatable {
   let x: Double
   let y: Double
}

// MARK: - Header

/// The headline numbers a rider screenshots: what, when, how far, how fast.
struct RideDetailHeader: Sendable, Equatable {

   let dateText: String
   let timeRangeText: String

   let distance: String
   let distanceUnit: String

   let rideTime: String
   let movingTime: String
   let stoppedTime: String

   let averageSpeed: String
   let speedUnit: String
}

// MARK: - Elevation

/// The altitude profile over distance, plus the totals it explains.
struct RideElevationReport: Sendable, Equatable {

   let points: [RideChartPoint]
   let gainText: String
   let lossText: String
   let maxAltitudeText: String
   let minAltitudeText: String
   let elevationUnit: String
   let distanceUnit: String

   /// Padded so a flat ride still draws a line with air around it instead of
   /// a stripe pinned to the frame.
   let yDomain: ClosedRange<Double>
}

// MARK: - Speed

/// Speed over distance, with the average drawn as a reference line.
struct RideSpeedReport: Sendable, Equatable {

   let points: [RideChartPoint]
   let averageValue: Double
   let averageText: String
   let maximumText: String
   let speedUnit: String
   let distanceUnit: String
}

// MARK: - Heart Rate

/// The pulse story: series over elapsed minutes plus its highs and lows.
struct RideHeartRateReport: Sendable, Equatable {

   let points: [RideChartPoint]
   let averageText: String
   let maximumText: String
   let minimumText: String

   /// The exact peaks, so the chart can flag the ride's high and low beat.
   let maximumPoint: RideChartPoint?
   let minimumPoint: RideChartPoint?

   let caloriesText: String?

   /// Set when the series was read back from Apple Health rather than
   /// recorded into the ride's own samples.
   let isFromAppleHealth: Bool
}

// MARK: - Weather

/// The sky this ride was ridden under, stamped at start and end.
struct RideDetailWeatherReport: Sendable, Equatable {

   let symbolName: String
   let conditionLabel: String

   /// "64°" for a steady sky, "64° → 68°" when the temperature moved.
   let temperatureText: String
   let feelsLikeText: String?
   let windText: String?
}

// MARK: - Radar

/// One vehicle pass placed on the traffic timeline.
struct RideRadarPassPoint: Sendable, Equatable, Identifiable {
   let id: Int
   let minutes: Double
   let distance: Double
   let isHighTier: Bool
}

/// The full traffic report: totals, density and every pass on a timeline.
struct RideRadarReport: Sendable, Equatable {

   let vehicleCountText: String
   let closestPassText: String
   let maximumClosingText: String
   let speedUnit: String

   /// Vehicles per mile or kilometer — the number that makes two roads
   /// comparable. `nil` on a ride too short to make density honest.
   let densityText: String?

   /// Passes that peaked at the high tier. `nil` when there were none.
   let highTierCountText: String?

   let points: [RideRadarPassPoint]
   let radarDistanceUnit: String

   /// Chart x-domain in minutes, so the timeline spans the whole ride even
   /// when the last pass happened early.
   let durationMinutes: Double
}
