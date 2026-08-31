//
//  RideRouteDownsampler.swift
//  BigV
//

import CoreLocation
import Foundation

/// Thins a GPS track down to what a map can actually show.
///
/// Full-fidelity position lives in SwiftData for HealthKit and GPX. A drawn
/// polyline needs far less: at any zoom a rider can hold on a handlebar, points
/// closer together than `minimumSpacing` land on the same pixel. Keeping the
/// display track short is what stops a multi-hour ride from getting slower and
/// slower to render.
///
/// Pure math with no framework side effects so it can be tested in isolation.
nonisolated enum RideRouteDownsampler {

   // MARK: - Configuration

   struct Configuration: Sendable {

      /// Minimum ground distance between two drawn points, in meters.
      var minimumSpacing: Double = 10

      /// Ceiling on drawn points. Past this the track is halved and the spacing
      /// doubled, so cost stays flat instead of growing with ride length.
      var maximumPointCount: Int = 3_000

      static let `default` = Configuration()
   }

   // MARK: - Constants

   private static let earthRadius: Double = 6_371_000
   private static let degreesToRadians: Double = .pi / 180

   // MARK: - Point Validity

   /// Rejects unusable coordinates, including the (0, 0) that a `RideSample`
   /// carries before it is populated. Null Island is never a bike ride.
   static func isUsable(_ coordinate: CLLocationCoordinate2D) -> Bool {
      guard CLLocationCoordinate2DIsValid(coordinate) else { return false }
      guard coordinate.latitude.isFinite, coordinate.longitude.isFinite else { return false }
      return coordinate.latitude != 0 || coordinate.longitude != 0
   }

   // MARK: - Spacing

   /// Equirectangular approximation. Well under a percent of error at the tens
   /// of meters this gates on, and it allocates nothing, unlike `CLLocation`.
   static func meters(
      from origin: CLLocationCoordinate2D,
      to destination: CLLocationCoordinate2D
   ) -> Double {
      let meanLatitude = (origin.latitude + destination.latitude) / 2 * degreesToRadians
      let deltaLatitude = (destination.latitude - origin.latitude) * degreesToRadians
      let deltaLongitude = (destination.longitude - origin.longitude) * degreesToRadians
      let easting = deltaLongitude * cos(meanLatitude)

      return earthRadius * (deltaLatitude * deltaLatitude + easting * easting).squareRoot()
   }

   static func isFarEnough(
      _ candidate: CLLocationCoordinate2D,
      from last: CLLocationCoordinate2D,
      spacing: Double
   ) -> Bool {
      meters(from: last, to: candidate) > spacing
   }

   // MARK: - Decimation

   /// Halves a track while always preserving both endpoints, so the drawn line
   /// still starts where the ride started and ends where the rider is.
   static func decimated(_ coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
      guard coordinates.count > 2 else { return coordinates }

      var thinned: [CLLocationCoordinate2D] = []
      thinned.reserveCapacity(coordinates.count / 2 + 1)

      for (index, coordinate) in coordinates.enumerated() where index.isMultiple(of: 2) {
         thinned.append(coordinate)
      }

      if coordinates.count.isMultiple(of: 2), let last = coordinates.last {
         thinned.append(last)
      }

      return thinned
   }

   // MARK: - Batch

   /// Applies the live rule to a finished track, for saved rides.
   static func route(
      from coordinates: [CLLocationCoordinate2D],
      configuration: Configuration = .default
   ) -> [CLLocationCoordinate2D] {
      var kept: [CLLocationCoordinate2D] = []
      var spacing = configuration.minimumSpacing

      for coordinate in coordinates where isUsable(coordinate) {
         if let last = kept.last, !isFarEnough(coordinate, from: last, spacing: spacing) {
            continue
         }

         kept.append(coordinate)

         if kept.count > configuration.maximumPointCount {
            kept = decimated(kept)
            spacing *= 2
         }
      }

      return kept
   }

   /// Ordering is re-established here because a SwiftData relationship makes no
   /// promise about it.
   static func route(
      from samples: [RideSample],
      configuration: Configuration = .default
   ) -> [CLLocationCoordinate2D] {
      let coordinates = samples
         .sorted { $0.timestamp < $1.timestamp }
         .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }

      return route(from: coordinates, configuration: configuration)
   }
}
