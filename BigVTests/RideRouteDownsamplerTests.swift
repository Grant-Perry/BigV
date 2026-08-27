//
//  RideRouteDownsamplerTests.swift
//  BigVTests
//

import CoreLocation
import Foundation
import Testing
@testable import BigV

@MainActor
struct RideRouteDownsamplerTests {

   // MARK: - Fixtures

   private static let origin = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)

   /// Meters per degree of latitude under the downsampler's own spherical model.
   ///
   /// Mirrored here so a fixture can be laid out at an exact spacing and the
   /// keep/drop rule can be asserted on precise counts. Absolute accuracy of the
   /// distance function is checked separately against Core Location.
   private static let metersPerLatitudeDegree = 6_371_000 * Double.pi / 180

   /// A straight line due north, where spacing is purely a latitude delta.
   private func northwardLine(count: Int, metersApart: Double) -> [CLLocationCoordinate2D] {
      let step = metersApart / Self.metersPerLatitudeDegree

      return (0..<count).map { index in
         CLLocationCoordinate2D(
            latitude: Self.origin.latitude + Double(index) * step,
            longitude: Self.origin.longitude
         )
      }
   }

   private func sample(index: Int, at reference: Date) -> RideSample {
      RideSample(
         timestamp: reference.addingTimeInterval(Double(index)),
         latitude: Self.origin.latitude + Double(index) * 0.0005,
         longitude: Self.origin.longitude,
         altitude: 100,
         speed: 8,
         distance: Double(index) * 50,
         grade: 0,
         course: 0
      )
   }

   // MARK: - Distance

   @Test func distanceMatchesCoreLocationWithinAPercent() {
      let destination = CLLocationCoordinate2D(latitude: 37.3405, longitude: -122.0012)
      let expected = CLLocation(latitude: Self.origin.latitude, longitude: Self.origin.longitude)
         .distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))

      let actual = RideRouteDownsampler.meters(from: Self.origin, to: destination)

      #expect(expected > 0)
      #expect(abs(actual - expected) / expected < 0.01)
   }

   // MARK: - Spacing Rule

   @Test func keepsEveryPointOnAWidelySpacedTrack() {
      let line = northwardLine(count: 10, metersApart: 25)

      #expect(RideRouteDownsampler.route(from: line).count == 10)
   }

   @Test func keepsAlternatePointsWhenSpacingIsJustOverHalfTheMinimum() {
      let line = northwardLine(count: 9, metersApart: 6)

      let route = RideRouteDownsampler.route(from: line)

      #expect(route.count == 5)
      #expect(route.map(\.latitude) == [0, 2, 4, 6, 8].map { line[$0].latitude })
   }

   @Test func collapsesATrackThatBarelyMoves() {
      // Eleven points two meters apart span twenty meters, so only the start and
      // the first point past ten meters survive.
      let line = northwardLine(count: 11, metersApart: 2)

      let route = RideRouteDownsampler.route(from: line)

      #expect(route.count == 2)
      #expect(route.first?.latitude == line[0].latitude)
      #expect(route.last?.latitude == line[6].latitude)
   }

   @Test func aStationaryRiderAddsNoPointsAfterTheFirst() {
      let line = Array(repeating: Self.origin, count: 500)

      #expect(RideRouteDownsampler.route(from: line).count == 1)
   }

   // MARK: - Degenerate Input

   @Test func zeroCoordinatesProduceNoRoute() {
      #expect(RideRouteDownsampler.route(from: [] as [CLLocationCoordinate2D]).isEmpty)
   }

   @Test func oneCoordinateProducesASinglePointThatIsNotDrawable() {
      let route = RideRouteDownsampler.route(from: [Self.origin])

      #expect(route.count == 1)
      #expect(RideRoute(coordinates: route).isDrawable == false)
   }

   @Test func unusableCoordinatesAreDiscarded() {
      let unusable = [
         CLLocationCoordinate2D(latitude: 0, longitude: 0),
         CLLocationCoordinate2D(latitude: 91, longitude: 10),
         CLLocationCoordinate2D(latitude: .nan, longitude: .nan),
         CLLocationCoordinate2D(latitude: 10, longitude: 181)
      ]

      #expect(unusable.allSatisfy { RideRouteDownsampler.isUsable($0) == false })
      #expect(RideRouteDownsampler.route(from: unusable).isEmpty)
      #expect(RideRouteDownsampler.isUsable(Self.origin))
   }

   @Test func unusableCoordinatesDoNotBreakTheSurroundingTrack() {
      var line = northwardLine(count: 4, metersApart: 25)
      line.insert(CLLocationCoordinate2D(latitude: 0, longitude: 0), at: 2)

      #expect(RideRouteDownsampler.route(from: line).count == 4)
   }

   // MARK: - Decimation

   @Test func decimationHalvesAnOddLengthTrackAndKeepsBothEnds() {
      let line = northwardLine(count: 9, metersApart: 25)

      let thinned = RideRouteDownsampler.decimated(line)

      #expect(thinned.count == 5)
      #expect(thinned.first?.latitude == line.first?.latitude)
      #expect(thinned.last?.latitude == line.last?.latitude)
   }

   @Test func decimationKeepsTheFinalPointOfAnEvenLengthTrack() {
      let line = northwardLine(count: 10, metersApart: 25)

      let thinned = RideRouteDownsampler.decimated(line)

      #expect(thinned.count == 6)
      #expect(thinned.first?.latitude == line.first?.latitude)
      #expect(thinned.last?.latitude == line.last?.latitude)
   }

   @Test func decimationLeavesTracksTooShortToThinAlone() {
      #expect(RideRouteDownsampler.decimated([]).isEmpty)
      #expect(RideRouteDownsampler.decimated([Self.origin]).count == 1)
      #expect(RideRouteDownsampler.decimated(northwardLine(count: 2, metersApart: 25)).count == 2)
   }

   // MARK: - Ceiling

   @Test func aLongTrackNeverExceedsTheCeiling() {
      let configuration = RideRouteDownsampler.Configuration(
         minimumSpacing: 5,
         maximumPointCount: 16
      )
      let line = northwardLine(count: 400, metersApart: 6)

      let route = RideRouteDownsampler.route(from: line, configuration: configuration)

      #expect(route.count > 1)
      #expect(route.count <= configuration.maximumPointCount)
      #expect(route.first?.latitude == line.first?.latitude)
   }

   // MARK: - Samples

   @Test func aSampleRouteIsOrderedByTimestamp() {
      let reference = Date(timeIntervalSince1970: 1_000_000)
      let samples = [3, 0, 4, 1, 2].map { sample(index: $0, at: reference) }

      let route = RideRouteDownsampler.route(from: samples)

      #expect(route.count == 5)
      #expect(route.map(\.latitude) == route.map(\.latitude).sorted())
   }

   @Test func aRideWithNoSamplesProducesNoRoute() {
      #expect(RideRouteDownsampler.route(from: [] as [RideSample]).isEmpty)
   }

   @Test func aRideWithOneSampleProducesARouteThatCannotBeDrawn() {
      let reference = Date(timeIntervalSince1970: 1_000_000)

      let route = RideRouteDownsampler.route(from: [sample(index: 0, at: reference)])

      #expect(route.count == 1)
      #expect(RideRoute(coordinates: route).isDrawable == false)
   }
}
