//
//  RideRouteRecorder.swift
//  BigV
//

import CoreLocation
import Foundation

/// Holds the live breadcrumb the map draws.
///
/// Deliberately not part of `RideState`. That struct is `Equatable` and is
/// republished on every accepted sample, so a track growing to thousands of
/// points would make every equality check and every view diff more expensive the
/// longer the rider stays out — the worst possible cost curve for a phone baking
/// on a handlebar. Keeping the track here means only the map observes it.
///
/// Appends are amortised constant time: a point is dropped unless it is more than
/// `spacing` from the last one, and once the track hits its ceiling it is halved
/// and the spacing doubled.
@Observable
@MainActor
final class RideRouteRecorder {

   // MARK: - Published State

   private(set) var coordinates: [CLLocationCoordinate2D] = []

   var hasRoute: Bool { coordinates.count > 1 }

   // MARK: - Private State

   private let configuration: RideRouteDownsampler.Configuration
   private var spacing: Double

   // MARK: - Initialization

   init(configuration: RideRouteDownsampler.Configuration = .default) {
      self.configuration = configuration
      self.spacing = configuration.minimumSpacing
   }

   // MARK: - Recording

   func append(_ coordinate: CLLocationCoordinate2D) {
      guard RideRouteDownsampler.isUsable(coordinate) else { return }

      if let last = coordinates.last,
         !RideRouteDownsampler.isFarEnough(coordinate, from: last, spacing: spacing) {
         return
      }

      coordinates.append(coordinate)

      guard coordinates.count > configuration.maximumPointCount else { return }

      coordinates = RideRouteDownsampler.decimated(coordinates)
      spacing *= 2

      DebugPrint(
         mode: .telemetry,
         "Route decimated to \(coordinates.count) points, spacing now \(spacing) m"
      )
   }

   func reset() {
      coordinates.removeAll(keepingCapacity: true)
      spacing = configuration.minimumSpacing
   }
}
