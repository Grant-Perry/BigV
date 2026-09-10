//
//  RideSplitSegmentBuilderTests.swift
//  BigVTests
//

import CoreLocation
import Foundation
import Testing
@testable import BigV

struct RideSplitSegmentBuilderTests {

   private static let origin = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
   private static let reference = Date(timeIntervalSince1970: 1_000_000)
   private static let metersPerLatitudeDegree = 6_371_000 * Double.pi / 180

   // MARK: - Distance

   @Test func slicesALapByDistanceAndLeavesTheNextLapAlone() throws {
      let probes = (0...6).map { index in
         probe(index: index, distance: Double(index) * 50)
      }
      let first = RideSplitWindow(
         id: .lap(1),
         startDistance: 0,
         endDistance: 150,
         startDate: Self.reference,
         endDate: Self.reference.addingTimeInterval(60)
      )
      let second = RideSplitWindow(
         id: .lap(2),
         startDistance: 150,
         endDistance: 300,
         startDate: Self.reference.addingTimeInterval(60),
         endDate: Self.reference.addingTimeInterval(120)
      )

      let segments = RideSplitSegmentBuilder.segments(windows: [first, second], probes: probes)

      #expect(segments.count == 2)
      let lap1 = try #require(segments.first { $0.id == .lap(1) })
      let lap2 = try #require(segments.first { $0.id == .lap(2) })

      #expect(lap1.route.isDrawable)
      #expect(lap2.route.isDrawable)
      #expect(lap1.route.coordinates.first?.latitude == probes[0].latitude)
      #expect(lap1.route.coordinates.last?.latitude == probes[3].latitude)
      #expect(lap2.route.coordinates.first?.latitude == probes[3].latitude)
      #expect(lap2.route.coordinates.last?.latitude == probes[6].latitude)
   }

   @Test func keepsLapAndClimbIdentitiesDistinct() {
      let probes = (0...4).map { index in
         probe(index: index, distance: Double(index) * 50)
      }
      let windows = [
         RideSplitWindow(
            id: .lap(1),
            startDistance: 0,
            endDistance: 100,
            startDate: Self.reference,
            endDate: Self.reference.addingTimeInterval(20)
         ),
         RideSplitWindow(
            id: .climb(1),
            startDistance: 50,
            endDistance: 200,
            startDate: Self.reference.addingTimeInterval(10),
            endDate: Self.reference.addingTimeInterval(40)
         )
      ]

      let segments = RideSplitSegmentBuilder.segments(windows: windows, probes: probes)
      let ids = Set(segments.map(\.id))

      #expect(ids.contains(.lap(1)))
      #expect(ids.contains(.climb(1)))
      #expect(ids.count == 2)
   }

   // MARK: - Time fallback

   @Test func fallsBackToTimeWhenDistanceDoesNotCoverTwoPoints() throws {
      let start = Self.reference
      let probes = (0...4).map { index in
         probe(index: index, distance: 0, timestamp: start.addingTimeInterval(Double(index) * 10))
      }
      let window = RideSplitWindow(
         id: .lap(1),
         startDistance: 1_000,
         endDistance: 2_000,
         startDate: start.addingTimeInterval(10),
         endDate: start.addingTimeInterval(30)
      )

      let segments = RideSplitSegmentBuilder.segments(windows: [window], probes: probes)
      let lap = try #require(segments.first)

      #expect(lap.id == .lap(1))
      #expect(lap.route.coordinates.count >= 2)
      #expect(lap.route.coordinates.first?.latitude == probes[1].latitude)
      #expect(lap.route.coordinates.last?.latitude == probes[3].latitude)
   }

   // MARK: - Degenerate

   @Test func skipsASplitWithFewerThanTwoUsablePoints() {
      let probes = [probe(index: 0, distance: 0), probe(index: 1, distance: 50)]
      let window = RideSplitWindow(
         id: .lap(1),
         startDistance: 0,
         endDistance: 10,
         startDate: Self.reference,
         endDate: Self.reference
      )

      #expect(RideSplitSegmentBuilder.segments(windows: [window], probes: probes).isEmpty)
   }

   @Test func discardsNullIslandInsideAWindow() {
      var probes = (0...3).map { index in
         probe(index: index, distance: Double(index) * 50)
      }
      probes[1] = RideSplitSegmentBuilder.Probe(
         timestamp: Self.reference.addingTimeInterval(1),
         latitude: 0,
         longitude: 0,
         distance: 50
      )

      let window = RideSplitWindow(
         id: .lap(1),
         startDistance: 0,
         endDistance: 150,
         startDate: Self.reference,
         endDate: Self.reference.addingTimeInterval(30)
      )
      let segments = RideSplitSegmentBuilder.segments(windows: [window], probes: probes)
      let latitudes = segments.first?.route.coordinates.map(\.latitude) ?? []

      #expect(!latitudes.contains(0))
      #expect(segments.first?.route.isDrawable == true)
   }

   // MARK: - Fixtures

   private func probe(
      index: Int,
      distance: Double,
      timestamp: Date? = nil
   ) -> RideSplitSegmentBuilder.Probe {
      let step = 25 / Self.metersPerLatitudeDegree
      return RideSplitSegmentBuilder.Probe(
         timestamp: timestamp ?? Self.reference.addingTimeInterval(Double(index)),
         latitude: Self.origin.latitude + Double(index) * step,
         longitude: Self.origin.longitude,
         distance: distance
      )
   }
}
