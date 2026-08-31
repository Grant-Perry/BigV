//
//  RideClimbProfileSeriesBuilder.swift
//  BigV
//

import Foundation

/// The climb chart's plotted form: axis-unit points, a per-point grade for the
/// colour ramp, and the playhead resolved into the same space.
///
/// Everything is converted here — meters to the rider's distance and elevation
/// units — so the chart never does math and a test can pin every coordinate.
struct RideClimbProfileSeries: Equatable {

   struct Point: Identifiable, Equatable {
      /// Index in the plotted series; stable for the life of one build.
      let id: Int

      /// Distance from the window start, in the rider's distance unit.
      let x: Double

      /// Altitude in the rider's elevation unit.
      let altitude: Double

      /// Grade climbing into this point, as a percentage. The first point
      /// borrows the second's, so the ramp has no grey lead-in.
      let grade: Double
   }

   let points: [Point]

   /// Altitude bounds padded for the chart, in display units.
   let altitudeRange: ClosedRange<Double>

   /// The rider, when they are inside the window.
   let playhead: Point?

   /// The window's span in display units, so climb markers can be projected.
   let xSpan: Double
}

// MARK: - Builder

/// Cuts a window out of a route's elevation profile and converts it for the
/// climb chart.
///
/// Pure so the windowing, thinning and grade math are all testable without a
/// chart in sight.
enum RideClimbProfileSeriesBuilder {

   /// Charts stay crisp and cheap under ~300 marks; a long route's profile can
   /// carry thousands of samples.
   static let maximumPointCount = 300

   /// The plotted series for `profile` between `start` and `end` meters.
   ///
   /// Returns `nil` when the window holds too little profile to draw a shape.
   static func series(
      profile: [RouteElevationSample],
      start: Double,
      end: Double,
      playheadDistance: Double?,
      playheadAltitude: Double?,
      system: RideUnitSystem
   ) -> RideClimbProfileSeries? {
      guard end > start else { return nil }

      let window = profile.filter { $0.distanceAlongRoute >= start && $0.distanceAlongRoute <= end }
      guard window.count > 1 else { return nil }

      let thinned = thin(window, to: maximumPointCount)

      var points: [RideClimbProfileSeries.Point] = []
      points.reserveCapacity(thinned.count)

      for (index, sample) in thinned.enumerated() {
         let previous = index > 0 ? thinned[index - 1] : thinned[index + 1 == thinned.count ? index : index + 1]
         let run = abs(sample.distanceAlongRoute - previous.distanceAlongRoute)
         let rise = index > 0
            ? sample.altitude - previous.altitude
            : previous.altitude - sample.altitude
         let grade = run > 0 ? rise / run * 100 : 0

         points.append(
            RideClimbProfileSeries.Point(
               id: index,
               x: distanceValue(sample.distanceAlongRoute - start, system: system),
               altitude: elevationValue(sample.altitude, system: system),
               grade: grade
            )
         )
      }

      let altitudes = points.map(\.altitude)
      guard let low = altitudes.min(), let high = altitudes.max() else { return nil }
      let padding = max((high - low) * 0.18, 2)

      var playhead: RideClimbProfileSeries.Point?
      if let playheadDistance, let playheadAltitude,
         playheadDistance >= start, playheadDistance <= end {
         playhead = RideClimbProfileSeries.Point(
            id: -1,
            x: distanceValue(playheadDistance - start, system: system),
            altitude: elevationValue(playheadAltitude, system: system),
            grade: 0
         )
      }

      return RideClimbProfileSeries(
         points: points,
         altitudeRange: (low - padding)...(high + padding),
         playhead: playhead,
         xSpan: distanceValue(end - start, system: system)
      )
   }

   // MARK: - Units

   /// Meters into the rider's distance axis unit (km or mi).
   static func distanceValue(_ meters: Double, system: RideUnitSystem) -> Double {
      system == .imperial ? meters / 1_609.344 : meters / 1_000
   }

   /// Meters into the rider's elevation unit (m or ft).
   static func elevationValue(_ meters: Double, system: RideUnitSystem) -> Double {
      system == .imperial ? meters * 3.280839895 : meters
   }

   // MARK: - Thinning

   /// Keeps every `stride`-th sample plus the last, preserving the endpoints
   /// that anchor the window.
   private static func thin(_ samples: [RouteElevationSample], to limit: Int) -> [RouteElevationSample] {
      guard samples.count > limit else { return samples }

      let stride = Double(samples.count - 1) / Double(limit - 1)
      var thinned: [RouteElevationSample] = []
      thinned.reserveCapacity(limit)

      for step in 0..<limit {
         thinned.append(samples[Int((Double(step) * stride).rounded())])
      }
      return thinned
   }
}
