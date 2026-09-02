//
//  RideFormatters.swift
//  BigV
//

import Foundation

/// Converts SI telemetry into rider-facing strings.
///
/// The ride engine stores everything in meters and meters/second. Unit
/// conversion happens here and nowhere else, steered by `RideUnitSystem`:
/// every formatter defaults to the persisted preference, and a caller that
/// needs live re-rendering (or the Watch, which mirrors the phone's choice)
/// passes the system explicitly.
nonisolated enum RideFormatters {

   // MARK: - Unit Labels

   /// Labels that never change with the measurement system. Speed, distance
   /// and elevation labels live on `RideUnitSystem`, because they do.
   enum Unit {
      static let grade = "%"
      static let cadence = "RPM"
      static let heartRate = "BPM"
      static let power = "W"

      /// Metres per hour on every bike computer, imperial included — VAM is
      /// defined in that unit and riders compare it across borders.
      static let verticalSpeed = "M/H"
   }

   static let placeholder = "—"

   // MARK: - Speed

   static func speed(_ metersPerSecond: Double, system: RideUnitSystem = .current) -> String {
      let unit: UnitSpeed = system == .imperial ? .milesPerHour : .kilometersPerHour
      let value = Measurement(value: max(0, metersPerSecond), unit: UnitSpeed.metersPerSecond)
         .converted(to: unit)
         .value
      return value.formatted(.number.precision(.fractionLength(1)))
   }

   // MARK: - Distance

   static func distance(_ meters: Double, system: RideUnitSystem = .current) -> String {
      let unit: UnitLength = system == .imperial ? .miles : .kilometers
      let value = Measurement(value: max(0, meters), unit: UnitLength.meters)
         .converted(to: unit)
         .value
      return value.formatted(.number.precision(.fractionLength(2)))
   }

   // MARK: - Elevation

   static func elevation(_ meters: Double, system: RideUnitSystem = .current) -> String {
      guard system == .imperial else {
         return meters.formatted(.number.precision(.fractionLength(0)))
      }
      let feet = Measurement(value: meters, unit: UnitLength.meters)
         .converted(to: .feet)
         .value
      return feet.formatted(.number.precision(.fractionLength(0)))
   }

   static func elevationGain(_ meters: Double, system: RideUnitSystem = .current) -> String {
      "+\(elevation(max(0, meters), system: system))"
   }

   static func elevationLoss(_ meters: Double, system: RideUnitSystem = .current) -> String {
      "-\(elevation(max(0, meters), system: system))"
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

   // MARK: - Temperature

   /// WeatherKit is read in Celsius and displayed on the rider's scale, so the
   /// conversion lands here with every other one.
   static func temperature(
      _ celsius: Double,
      unit: RideTemperatureUnit = .current
   ) -> String {
      "\(temperatureNumber(celsius, unit: unit))\(unit.suffix)"
   }

   /// Bare degrees for dense readouts — the chip and the hourly strip, where the
   /// scale is already established by the surrounding card.
   static func temperatureDegrees(
      _ celsius: Double,
      unit: RideTemperatureUnit = .current
   ) -> String {
      "\(temperatureNumber(celsius, unit: unit))°"
   }

   /// The numeral alone, for the hero where the unit is set in its own type.
   static func temperatureNumber(
      _ celsius: Double,
      unit: RideTemperatureUnit = .current
   ) -> String {
      let value = Measurement(value: celsius, unit: UnitTemperature.celsius)
         .converted(to: unit.measurementUnit)
         .value
      return "\(Int(value.rounded()))"
   }

   // MARK: - Grade

   static func grade(_ percent: Double) -> String {
      percent.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always(includingZero: false)))
   }

   // MARK: - Vertical Speed

   /// VAM in whole meters/hour — the unit the number is defined in, worldwide;
   /// no bike computer converts it. Descent reads as zero: VAM is a climbing
   /// figure and a negative one is noise, not information.
   static func verticalSpeed(_ metersPerHour: Double) -> String {
      max(0, metersPerHour).formatted(.number.precision(.fractionLength(0)))
   }

   // MARK: - Accuracy

   static func accuracy(_ meters: Double, system: RideUnitSystem = .current) -> String {
      guard system == .imperial else {
         return "\(meters.formatted(.number.precision(.fractionLength(0)))) m"
      }
      let feet = Measurement(value: meters, unit: UnitLength.meters)
         .converted(to: .feet)
         .value
      return "\(feet.formatted(.number.precision(.fractionLength(0)))) ft"
   }

   // MARK: - Radar Distance

   /// A rear-radar range: short-range figures a rider reacts to, so metric
   /// reads whole meters and imperial reads feet rounded to fives — the same
   /// convention the Varia app uses. Never miles or kilometers; the radar's
   /// whole world is 140 m.
   static func radarDistance(_ meters: Double, system: RideUnitSystem = .current) -> String {
      let clamped = max(0, meters)

      guard system == .imperial else {
         return "\(Int(clamped.rounded())) m"
      }

      let feet = Measurement(value: clamped, unit: UnitLength.meters)
         .converted(to: .feet)
         .value
      let rounded = Int((feet / 5).rounded()) * 5
      return "\(rounded) ft"
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
