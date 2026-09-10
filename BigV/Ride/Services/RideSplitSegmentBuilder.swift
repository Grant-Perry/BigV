//
//  RideSplitSegmentBuilder.swift
//  BigV
//

import CoreLocation
import Foundation

/// Cuts each lap and climb out of the ride's samples so the detail map can
/// light one slice without walking SwiftData while a finger is moving.
enum RideSplitSegmentBuilder {

   /// One probe along the stored track. Distance is the first key; time is the
   /// fallback when a split's meter window does not match any sample.
   struct Probe: Sendable, Equatable {
      let timestamp: Date
      let latitude: Double
      let longitude: Double
      let distance: Double
   }

   // MARK: - Ride

   /// Projects the ride's stored splits. Call from the main actor: SwiftData
   /// models are not `Sendable`.
   @MainActor
   static func segments(
      laps: [RideLap],
      climbs: [RideClimbSplit],
      samples: [RideSample]
   ) -> [RideSplitSegment] {
      let windows = laps.map(window(for:)) + climbs.map(window(for:))
      let probes = samples.map { sample in
         Probe(
            timestamp: sample.timestamp,
            latitude: sample.latitude,
            longitude: sample.longitude,
            distance: sample.distance
         )
      }
      return segments(windows: windows, probes: probes)
   }

   // MARK: - Geometry

   /// Distance first, clock second. A lap is a fact about meters; timestamps
   /// only stand in when the stored distances do not cover two usable points.
   static func segments(
      windows: [RideSplitWindow],
      probes: [Probe]
   ) -> [RideSplitSegment] {
      let ordered = probes.sorted { $0.timestamp < $1.timestamp }

      return windows.compactMap { window in
         let coordinates = slice(window, from: ordered)
         let route = RideRoute(coordinates: RideRouteDownsampler.route(from: coordinates))
         guard route.isDrawable else { return nil }
         return RideSplitSegment(id: window.id, route: route)
      }
   }

   // MARK: - Windows

   @MainActor
   private static func window(for lap: RideLap) -> RideSplitWindow {
      RideSplitWindow(
         id: .lap(lap.index),
         startDistance: lap.startDistance,
         endDistance: lap.endDistance,
         startDate: lap.startDate,
         endDate: lap.endDate
      )
   }

   @MainActor
   private static func window(for climb: RideClimbSplit) -> RideSplitWindow {
      RideSplitWindow(
         id: .climb(climb.index),
         startDistance: climb.startDistance,
         endDistance: climb.endDistance,
         startDate: climb.startDate,
         endDate: climb.endDate
      )
   }

   // MARK: - Slice

   private static func slice(_ window: RideSplitWindow, from probes: [Probe]) -> [CLLocationCoordinate2D] {
      let byDistance = coordinates(
         in: probes,
         matching: { $0.distance >= window.startDistance && $0.distance <= window.endDistance }
      )
      if byDistance.count > 1 {
         return byDistance
      }

      return coordinates(
         in: probes,
         matching: { $0.timestamp >= window.startDate && $0.timestamp <= window.endDate }
      )
   }

   private static func coordinates(
      in probes: [Probe],
      matching isInside: (Probe) -> Bool
   ) -> [CLLocationCoordinate2D] {
      probes.compactMap { probe in
         guard isInside(probe) else { return nil }
         let coordinate = CLLocationCoordinate2D(latitude: probe.latitude, longitude: probe.longitude)
         return RideRouteDownsampler.isUsable(coordinate) ? coordinate : nil
      }
   }
}
