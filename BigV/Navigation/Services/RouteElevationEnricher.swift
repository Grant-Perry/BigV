//
//  RouteElevationEnricher.swift
//  BigV
//

import CoreLocation
import Foundation

/// Attaches an elevation profile and its climbs to a planned route.
///
/// Apple's routes arrive altitude-free, so this downsamples the polyline to a
/// spacing terrain actually resolves at, asks Open-Meteo for the heights in
/// batches, and runs `ClimbDetector` over the result.
///
/// Fail-soft is the contract: a route that cannot be enriched is returned
/// exactly as it came in, still perfectly rideable — the climb page and the
/// remaining-ascent tile simply stay hidden. Elevation is a bonus, never a
/// gate on navigation.
nonisolated struct RouteElevationEnricher: Sendable {

   // MARK: - Configuration

   struct Configuration: Sendable {

      /// Meters between profile samples. Open-Meteo's terrain model is ~90 m
      /// cells, so asking more often than this buys noise, not detail.
      var sampleSpacing: CLLocationDistance = 75

      /// Coordinates per request, matching the API's ceiling.
      var batchSize: Int = RouteElevationClient.maximumBatchSize

      static let `default` = Configuration()
   }

   // MARK: - Dependencies

   private let client: any RouteElevationProviding
   private let configuration: Configuration

   init(
      client: any RouteElevationProviding = RouteElevationClient(),
      configuration: Configuration = .default
   ) {
      self.client = client
      self.configuration = configuration
   }

   // MARK: - Enrichment

   /// The route with a profile and climbs attached, or the route untouched
   /// when it already has one, has no geometry worth profiling, or the fetch
   /// fails.
   func enriched(_ route: PlannedRoute) async -> PlannedRoute {
      guard route.elevationProfile.isEmpty else { return route }

      let sampled = Self.samplePoints(
         along: route.coordinates,
         spacing: configuration.sampleSpacing
      )
      guard sampled.coordinates.count > 1 else { return route }

      var altitudes: [Double] = []
      altitudes.reserveCapacity(sampled.coordinates.count)

      do {
         for batch in Self.batches(of: sampled.coordinates, size: configuration.batchSize) {
            altitudes += try await client.elevations(for: batch)
         }
      } catch {
         DebugPrint(mode: .navigation, "Elevation enrich failed: \(error)")
         return route
      }

      guard altitudes.count == sampled.coordinates.count else { return route }

      let profile = Self.profile(
         distances: sampled.distances,
         altitudes: altitudes,
         claimedDistance: route.distance
      )

      var enriched = route
      enriched.elevationProfile = profile
      enriched.climbs = ClimbDetector.climbs(in: profile)

      DebugPrint(
         mode: .navigation,
         "Enriched route \(route.name): \(profile.count) samples, \(enriched.climbs.count) climb(s)"
      )

      return enriched
   }

   // MARK: - Downsampling

   /// The polyline thinned to profile spacing, with each kept point's
   /// cumulative distance along the drawn geometry.
   ///
   /// Both endpoints always survive: a profile that starts late or stops short
   /// would misplace every climb against guidance progress.
   static func samplePoints(
      along coordinates: [CLLocationCoordinate2D],
      spacing: CLLocationDistance
   ) -> (coordinates: [CLLocationCoordinate2D], distances: [CLLocationDistance]) {
      let usable = coordinates.filter(RideRouteDownsampler.isUsable)
      guard usable.count > 1 else { return ([], []) }

      var kept: [CLLocationCoordinate2D] = [usable[0]]
      var distances: [CLLocationDistance] = [0]

      var travelled: CLLocationDistance = 0
      var sinceLastKept: CLLocationDistance = 0

      for (previous, coordinate) in zip(usable, usable.dropFirst()) {
         let step = RideRouteDownsampler.meters(from: previous, to: coordinate)
         travelled += step
         sinceLastKept += step

         guard sinceLastKept >= spacing else { continue }

         kept.append(coordinate)
         distances.append(travelled)
         sinceLastKept = 0
      }

      // The last coordinate is the route end; when the tail is shorter than
      // the spacing, replace the previous kept point rather than appending a
      // sliver segment, so no gap ever falls under the spacing.
      if let lastKept = distances.last, travelled - lastKept < spacing, kept.count > 1 {
         kept.removeLast()
         distances.removeLast()
      }
      kept.append(usable[usable.count - 1])
      distances.append(travelled)

      return (kept, distances)
   }

   // MARK: - Batching

   static func batches(
      of coordinates: [CLLocationCoordinate2D],
      size: Int
   ) -> [[CLLocationCoordinate2D]] {
      guard size > 0 else { return [coordinates] }

      return stride(from: 0, to: coordinates.count, by: size).map {
         Array(coordinates[$0..<min($0 + size, coordinates.count)])
      }
   }

   // MARK: - Profile Assembly

   /// A profile from provider-carried altitudes — the GPX path, no network.
   ///
   /// GPX tracks log a point every few meters, far denser than terrain
   /// resolves, so the pairs are thinned to profile spacing before scaling.
   /// Empty or misaligned altitudes yield an empty profile, never a guess.
   static func profile(
      coordinates: [CLLocationCoordinate2D],
      altitudes: [Double],
      claimedDistance: CLLocationDistance,
      spacing: CLLocationDistance = Configuration.default.sampleSpacing
   ) -> [RouteElevationSample] {
      guard coordinates.count == altitudes.count, coordinates.count > 1 else { return [] }

      var distances: [CLLocationDistance] = [0]
      var kept: [Double] = [altitudes[0]]

      var travelled: CLLocationDistance = 0
      var sinceLastKept: CLLocationDistance = 0

      for index in 1..<coordinates.count {
         let step = RideRouteDownsampler.meters(
            from: coordinates[index - 1],
            to: coordinates[index]
         )
         travelled += step
         sinceLastKept += step

         let isLast = index == coordinates.count - 1
         guard sinceLastKept >= spacing || isLast else { continue }

         distances.append(travelled)
         kept.append(altitudes[index])
         sinceLastKept = 0
      }

      return profile(distances: distances, altitudes: kept, claimedDistance: claimedDistance)
   }

   /// Pairs distances with altitudes, scaled into the provider's distance
   /// space — the space `RouteGuidanceProgress.distanceAlongRoute` reports in.
   ///
   /// Mirrors `RouteGuidanceEngine`'s scaling rule exactly: a provider's
   /// claimed total and its drawn geometry rarely agree, and a profile left in
   /// geometry space would drift away from the playhead over a long route.
   static func profile(
      distances: [CLLocationDistance],
      altitudes: [Double],
      claimedDistance: CLLocationDistance
   ) -> [RouteElevationSample] {
      guard distances.count == altitudes.count,
            let geometryLength = distances.last,
            geometryLength > 0
      else { return [] }

      let ratio = claimedDistance / geometryLength
      let scale = claimedDistance > 0 && (0.5...2).contains(ratio) ? ratio : 1

      return zip(distances, altitudes).map {
         RouteElevationSample(distanceAlongRoute: $0 * scale, altitude: $1)
      }
   }
}
