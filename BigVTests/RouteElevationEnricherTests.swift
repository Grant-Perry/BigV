//
//  RouteElevationEnricherTests.swift
//  BigVTests
//

import CoreLocation
import Foundation
import Testing
@testable import BigV

@MainActor
struct RouteElevationEnricherTests {

   // MARK: - Fixtures

   private static let origin = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)

   /// A line running east, one vertex every 20 meters.
   private func straightLine(length: Double) -> [CLLocationCoordinate2D] {
      stride(from: 0, through: length, by: 20).map {
         RouteGuidanceTestGeography.coordinate(east: $0, north: 0, from: Self.origin)
      }
   }

   private func route(_ coordinates: [CLLocationCoordinate2D], distance: Double) -> PlannedRoute {
      PlannedRoute(
         id: UUID(),
         source: .appleMaps,
         name: "Test Route",
         coordinates: coordinates,
         distance: distance,
         expectedTravelTime: 0,
         maneuvers: [],
         advisories: []
      )
   }

   /// Terrain that rises east at a fixed grade and remembers each batch it was
   /// asked for, so the test can check batching without a network.
   private actor ScriptedTerrain: RouteElevationProviding {

      private(set) var batchSizes: [Int] = []
      private let gradePercent: Double
      private let fails: Bool

      init(gradePercent: Double = 0, fails: Bool = false) {
         self.gradePercent = gradePercent
         self.fails = fails
      }

      func elevations(for coordinates: [CLLocationCoordinate2D]) async throws -> [Double] {
         if fails { throw RouteElevationClientFailure.badResponse }
         batchSizes.append(coordinates.count)

         let metersPerDegreeLongitude = 111_320 * cos(Self.originLatitude * .pi / 180)
         return coordinates.map {
            100 + ($0.longitude - Self.originLongitude) * metersPerDegreeLongitude * gradePercent / 100
         }
      }

      private static let originLatitude = 37.3349
      private static let originLongitude = -122.0090
   }

   // MARK: - Downsampling

   @Test func samplePointsKeepSpacingAndBothEndpoints() throws {
      let line = straightLine(length: 1_000)
      let sampled = RouteElevationEnricher.samplePoints(along: line, spacing: 75)

      #expect(sampled.coordinates.count == sampled.distances.count)
      #expect(sampled.distances.first == 0)

      // The end always survives, at the full travelled length — measured
      // geodesically, so a nominal kilometer reads a meter or two off.
      let last = try #require(sampled.distances.last)
      #expect(abs(last - 1_000) < 5)

      // Every kept gap is at least the spacing; none is wildly more than one
      // vertex over it.
      for (previous, next) in zip(sampled.distances, sampled.distances.dropFirst()) {
         #expect(next - previous >= 74)
         #expect(next - previous <= 200)
      }

      // ~1 km at 75 m spacing lands near 14 samples, not the 51 vertices.
      #expect(sampled.coordinates.count < 20)
   }

   @Test func aTinyRouteDownsamplesToNothing() {
      let sampled = RouteElevationEnricher.samplePoints(along: [Self.origin], spacing: 75)
      #expect(sampled.coordinates.isEmpty)
   }

   // MARK: - Batching

   @Test func batchesRespectTheAPICeiling() {
      let line = straightLine(length: 5_000)
      let sampled = RouteElevationEnricher.samplePoints(along: line, spacing: 20)
      let batches = RouteElevationEnricher.batches(of: sampled.coordinates, size: 100)

      #expect(batches.allSatisfy { $0.count <= 100 })
      #expect(batches.dropLast().allSatisfy { $0.count == 100 })
      #expect(batches.reduce(0) { $0 + $1.count } == sampled.coordinates.count)
   }

   @Test func aShortListIsOneBatch() {
      let batches = RouteElevationEnricher.batches(of: straightLine(length: 100), size: 100)
      #expect(batches.count == 1)
   }

   // MARK: - Enrichment

   @Test func enrichedAttachesProfileAndClimbs() async throws {
      // 10 km rising at 5% the whole way: one obvious climb.
      let terrain = ScriptedTerrain(gradePercent: 5)
      let enricher = RouteElevationEnricher(client: terrain)
      let line = straightLine(length: 10_000)

      let enriched = await enricher.enriched(route(line, distance: 10_000))

      #expect(enriched.hasElevationProfile)
      #expect(enriched.climbs.count == 1)

      let climb = try #require(enriched.climbs.first)
      #expect(abs(climb.averageGrade - 5) < 0.5)

      // 10 km at 75 m spacing is ~125 samples: two API calls, both under
      // the ceiling.
      let sizes = await terrain.batchSizes
      #expect(sizes.count == 2)
      #expect(sizes.allSatisfy { $0 <= RouteElevationClient.maximumBatchSize })
   }

   @Test func aFailedFetchReturnsTheRouteUntouched() async {
      let terrain = ScriptedTerrain(fails: true)
      let enricher = RouteElevationEnricher(client: terrain)
      let original = route(straightLine(length: 2_000), distance: 2_000)

      let enriched = await enricher.enriched(original)

      #expect(enriched.id == original.id)
      #expect(!enriched.hasElevationProfile)
      #expect(enriched.climbs.isEmpty)
   }

   @Test func anAlreadyEnrichedRouteIsNotFetchedAgain() async {
      let terrain = ScriptedTerrain()
      let enricher = RouteElevationEnricher(client: terrain)

      var original = route(straightLine(length: 2_000), distance: 2_000)
      original.elevationProfile = [
         RouteElevationSample(distanceAlongRoute: 0, altitude: 100),
         RouteElevationSample(distanceAlongRoute: 2_000, altitude: 120)
      ]

      let enriched = await enricher.enriched(original)

      #expect(enriched.elevationProfile == original.elevationProfile)
      #expect(await terrain.batchSizes.isEmpty)
   }

   // MARK: - Profile Scaling

   @Test func theProfileScalesIntoTheProvidersDistanceSpace() throws {
      // The provider claims 1 100 m for geometry that measures 1 000 m — the
      // profile must live in the provider's space, where guidance progress is.
      let profile = RouteElevationEnricher.profile(
         distances: [0, 500, 1_000],
         altitudes: [100, 110, 120],
         claimedDistance: 1_100
      )

      #expect(profile.count == 3)
      #expect(try #require(profile.last).distanceAlongRoute == 1_100)
      #expect(profile[1].distanceAlongRoute == 550)
   }

   @Test func anAbsurdClaimIsIgnored() throws {
      // Three times the geometry cannot be a scaling truth; the profile stays
      // in geometry space rather than stretching onto it.
      let profile = RouteElevationEnricher.profile(
         distances: [0, 1_000],
         altitudes: [100, 120],
         claimedDistance: 3_000
      )

      #expect(try #require(profile.last).distanceAlongRoute == 1_000)
   }
}
