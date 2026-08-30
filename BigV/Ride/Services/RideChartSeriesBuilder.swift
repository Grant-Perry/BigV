//
//  RideChartSeriesBuilder.swift
//  BigV
//

import Foundation

/// Builds chart-ready reports from ride samples for detail and live cockpit.
///
/// Shared between post-ride detail and the in-progress hero so both surfaces
/// plot the same series with the same downsampling.
enum RideChartSeriesBuilder {

   // MARK: - Tuning

   /// Ceiling on plotted points per chart. A three-hour ride stores ~10k
   /// samples; a chart a palm wide cannot show more than a couple hundred.
   static let maximumChartPoints = 240

   /// Below this many pulsed samples the ride's own series is too thin to
   /// chart, and Apple Health is asked instead on the detail screen.
   static let minimumOwnHeartRateSamples = 10

   // MARK: - Elevation

   static func elevationReport(
      for ride: Ride,
      samples: [RideSample],
      system: RideUnitSystem
   ) -> RideElevationReport? {
      elevationReport(
         samples: samples,
         elevationGain: ride.elevationGain,
         elevationLoss: ride.elevationLoss,
         system: system
      )
   }

   static func elevationReport(
      samples: [RideSample],
      elevationGain: Double,
      elevationLoss: Double,
      system: RideUnitSystem
   ) -> RideElevationReport? {
      guard samples.count > 2 else { return nil }

      let points = downsampled(samples).map { sample in
         RideChartPoint(
            x: distanceValue(sample.distance, system: system),
            y: elevationValue(sample.altitude, system: system)
         )
      }

      guard let minY = points.map(\.y).min(),
            let maxY = points.map(\.y).max()
      else { return nil }

      // A dead-flat ride still gets headroom so the line reads as terrain.
      let minimumPadding: Double = system == .imperial ? 15 : 5
      let padding = max((maxY - minY) * 0.2, minimumPadding)

      return RideElevationReport(
         points: points,
         gainText: RideFormatters.elevationGain(elevationGain, system: system),
         lossText: RideFormatters.elevationLoss(elevationLoss, system: system),
         maxAltitudeText: maxY.formatted(.number.precision(.fractionLength(0))),
         minAltitudeText: minY.formatted(.number.precision(.fractionLength(0))),
         elevationUnit: system.elevationUnit,
         distanceUnit: system.distanceUnit,
         yDomain: (minY - padding)...(maxY + padding)
      )
   }

   // MARK: - Speed

   static func speedReport(
      for ride: Ride,
      samples: [RideSample],
      system: RideUnitSystem
   ) -> RideSpeedReport? {
      speedReport(
         samples: samples,
         averageSpeed: ride.averageSpeed,
         maximumSpeed: ride.maximumSpeed,
         system: system
      )
   }

   static func speedReport(
      samples: [RideSample],
      averageSpeed: Double,
      maximumSpeed: Double,
      system: RideUnitSystem
   ) -> RideSpeedReport? {
      guard samples.count > 2 else { return nil }

      let points = downsampled(samples).map { sample in
         RideChartPoint(
            x: distanceValue(sample.distance, system: system),
            y: speedValue(sample.speed, system: system)
         )
      }

      return RideSpeedReport(
         points: points,
         averageValue: speedValue(averageSpeed, system: system),
         averageText: RideFormatters.speed(averageSpeed, system: system),
         maximumText: RideFormatters.speed(maximumSpeed, system: system),
         speedUnit: system.speedUnit,
         distanceUnit: system.distanceUnit
      )
   }

   // MARK: - Heart Rate

   static func heartRateReport(
      for ride: Ride,
      samples: [RideSample]
   ) -> RideHeartRateReport? {
      let pulsed = samples.compactMap { sample -> (Date, Double)? in
         guard let beats = sample.heartRate, beats > 0 else { return nil }
         return (sample.timestamp, beats)
      }

      guard pulsed.count >= minimumOwnHeartRateSamples else { return nil }

      return heartRateReport(
         beats: pulsed,
         startDate: ride.startDate,
         calories: ride.activeEnergy,
         isFromAppleHealth: false
      )
   }

   static func heartRateReport(
      beats: [(timestamp: Date, beatsPerMinute: Double)],
      startDate: Date,
      calories: Double?,
      isFromAppleHealth: Bool
   ) -> RideHeartRateReport? {
      guard !beats.isEmpty else { return nil }

      let allPoints = beats.map { beat in
         RideChartPoint(
            x: max(0, beat.timestamp.timeIntervalSince(startDate) / 60),
            y: beat.beatsPerMinute
         )
      }

      guard let maximum = allPoints.max(by: { $0.y < $1.y }),
            let minimum = allPoints.min(by: { $0.y < $1.y })
      else { return nil }

      let average = allPoints.map(\.y).reduce(0, +) / Double(allPoints.count)

      return RideHeartRateReport(
         points: downsampled(allPoints),
         averageText: RideFormatters.heartRate(average),
         maximumText: RideFormatters.heartRate(maximum.y),
         minimumText: RideFormatters.heartRate(minimum.y),
         maximumPoint: maximum,
         minimumPoint: minimum,
         caloriesText: caloriesText(calories),
         isFromAppleHealth: isFromAppleHealth
      )
   }

   static func withCalories(
      _ calories: Double?,
      applied report: RideHeartRateReport
   ) -> RideHeartRateReport {
      guard report.caloriesText == nil, let calories else { return report }

      return RideHeartRateReport(
         points: report.points,
         averageText: report.averageText,
         maximumText: report.maximumText,
         minimumText: report.minimumText,
         maximumPoint: report.maximumPoint,
         minimumPoint: report.minimumPoint,
         caloriesText: caloriesText(calories),
         isFromAppleHealth: report.isFromAppleHealth
      )
   }

   static func caloriesText(_ kilocalories: Double?) -> String? {
      guard let kilocalories, kilocalories > 0 else { return nil }
      return kilocalories.formatted(.number.precision(.fractionLength(0)))
   }

   // MARK: - Unit Conversion

   static func distanceValue(_ meters: Double, system: RideUnitSystem) -> Double {
      system == .imperial ? meters / 1_609.344 : meters / 1_000
   }

   static func elevationValue(_ meters: Double, system: RideUnitSystem) -> Double {
      system == .imperial ? meters * 3.28084 : meters
   }

   static func speedValue(_ metersPerSecond: Double, system: RideUnitSystem) -> Double {
      metersPerSecond * (system == .imperial ? 2.236936 : 3.6)
   }

   static func radarDistanceValue(_ meters: Double, system: RideUnitSystem) -> Double {
      system == .imperial ? meters * 3.28084 : meters
   }

   // MARK: - Radar

   static func radarReport(
      for ride: Ride,
      system: RideUnitSystem
   ) -> RideRadarReport? {
      let events = ride.radarEvents.sorted { $0.timestamp < $1.timestamp }
      let wallMinutes = max(
         1,
         (ride.endDate ?? ride.startDate.addingTimeInterval(ride.duration))
            .timeIntervalSince(ride.startDate) / 60
      )

      return radarReport(
         events: events,
         startDate: ride.startDate,
         durationMinutes: wallMinutes,
         vehicleCount: ride.vehicleCount,
         closestPassDistance: ride.closestPassDistance,
         maximumClosingSpeed: ride.maximumClosingSpeed,
         distanceMeters: ride.distance,
         system: system
      )
   }

   static func radarReport(
      events: [RideRadarEvent],
      startDate: Date,
      durationMinutes: Double,
      vehicleCount: Int,
      closestPassDistance: Double?,
      maximumClosingSpeed: Double?,
      distanceMeters: Double,
      system: RideUnitSystem
   ) -> RideRadarReport? {
      guard vehicleCount > 0 else { return nil }

      let wallMinutes = max(1, durationMinutes)
      let points = events.enumerated().map { index, event in
         RideRadarPassPoint(
            id: index,
            minutes: min(
               wallMinutes,
               max(0, event.timestamp.timeIntervalSince(startDate) / 60)
            ),
            distance: radarDistanceValue(event.minimumDistance, system: system),
            isHighTier: event.peakTier == .high
         )
      }

      let highCount = events.count(where: { $0.peakTier == .high })

      return RideRadarReport(
         vehicleCountText: "\(vehicleCount)",
         closestPassText: closestPassDistance
            .map { RideFormatters.radarDistance($0, system: system) }
            ?? RideFormatters.placeholder,
         maximumClosingText: maximumClosingSpeed
            .map { RideFormatters.speed($0, system: system) }
            ?? RideFormatters.placeholder,
         speedUnit: system.speedUnit,
         densityText: radarDensityText(count: vehicleCount, meters: distanceMeters, system: system),
         highTierCountText: highCount > 0 ? "\(highCount)" : nil,
         points: points,
         radarDistanceUnit: system == .imperial ? "FT" : "M",
         durationMinutes: wallMinutes
      )
   }

   static func radarDensityText(
      count: Int,
      meters: Double,
      system: RideUnitSystem
   ) -> String? {
      let distance = distanceValue(meters, system: system)
      guard distance >= 0.5 else { return nil }

      let density = Double(count) / distance
      let unit = system == .imperial ? "mi" : "km"
      return "\(density.formatted(.number.precision(.fractionLength(1)))) / \(unit)"
   }

   // MARK: - Downsampling

   static func downsampled(_ samples: [RideSample]) -> [RideSample] {
      downsampled(samples, limit: maximumChartPoints)
   }

   static func downsampled(_ points: [RideChartPoint]) -> [RideChartPoint] {
      downsampled(points, limit: maximumChartPoints)
   }

   /// Stride-thins to the chart ceiling while always keeping the last element,
   /// so the profile ends where the ride ended.
   static func downsampled<Element>(_ elements: [Element], limit: Int) -> [Element] {
      guard elements.count > limit else { return elements }

      let stride = Double(elements.count) / Double(limit)
      var kept: [Element] = []
      kept.reserveCapacity(limit + 1)

      for index in 0..<limit {
         kept.append(elements[Int(Double(index) * stride)])
      }

      if let last = elements.last {
         kept.append(last)
      }

      return kept
   }
}
