//
//  RideFormatters.swift
//  BigV
//

import Foundation

/// Converts SI telemetry into rider-facing strings.
///
/// The ride engine stores everything in meters and meters/second. Imperial
/// conversion happens here and nowhere else.
nonisolated enum RideFormatters {

   // MARK: - Unit Labels

   enum Unit {
      static let speed = "MPH"
      static let distance = "MI"
      static let elevation = "FT"
      static let grade = "%"
      static let cadence = "RPM"
      static let heartRate = "BPM"
      static let power = "W"
   }

   static let placeholder = "—"

   // MARK: - Speed

   static func speed(_ metersPerSecond: Double) -> String {
      let milesPerHour = Measurement(value: max(0, metersPerSecond), unit: UnitSpeed.metersPerSecond)
         .converted(to: .milesPerHour)
         .value
      return milesPerHour.formatted(.number.precision(.fractionLength(1)))
   }

   // MARK: - Distance

   static func distance(_ meters: Double) -> String {
      let miles = Measurement(value: max(0, meters), unit: UnitLength.meters)
         .converted(to: .miles)
         .value
      return miles.formatted(.number.precision(.fractionLength(2)))
   }

   // MARK: - Elevation

   static func elevation(_ meters: Double) -> String {
      let feet = Measurement(value: meters, unit: UnitLength.meters)
         .converted(to: .feet)
         .value
      return feet.formatted(.number.precision(.fractionLength(0)))
   }

   static func elevationGain(_ meters: Double) -> String {
      "+\(elevation(max(0, meters)))"
   }

   static func elevationLoss(_ meters: Double) -> String {
      "-\(elevation(max(0, meters)))"
   }

   // MARK: - Duration

   static func duration(_ interval: TimeInterval) -> String {
      let total = Int(max(0, interval))
      let hours = total / 3600
      let minutes = (total % 3600) / 60
      let seconds = total % 60

      return hours > 0
         ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
         : String(format: "%d:%02d", minutes, seconds)
   }

   // MARK: - Heart Rate

   static func heartRate(_ beatsPerMinute: Double) -> String {
      beatsPerMinute.rounded().formatted(.number.precision(.fractionLength(0)))
   }

   // MARK: - Grade

   static func grade(_ percent: Double) -> String {
      percent.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always(includingZero: false)))
   }

   // MARK: - Accuracy

   static func accuracy(_ meters: Double) -> String {
      "\(meters.formatted(.number.precision(.fractionLength(0))) ) m"
   }

   // MARK: - Heading

   /// 16-point cardinal direction. Returns `nil` for an unknown course.
   static func cardinal(_ degrees: Double) -> String? {
      guard degrees >= 0 else { return nil }

      let points = [
         "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"
      ]
      let normalized = normalizedHeading(degrees)
      let index = Int((normalized / 22.5).rounded()) % points.count
      return points[index]
   }

   /// Whole-degree bearing. Returns `nil` for an unknown course.
   static func headingDegrees(_ degrees: Double) -> String? {
      guard degrees >= 0 else { return nil }
      let rounded = Int(normalizedHeading(degrees).rounded()) % 360
      return "\(rounded)°"
   }

   private static func normalizedHeading(_ degrees: Double) -> Double {
      let wrapped = degrees.truncatingRemainder(dividingBy: 360)
      return wrapped < 0 ? wrapped + 360 : wrapped
   }
}
