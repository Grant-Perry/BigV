//
//  GPXRouteImporterTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

@MainActor
struct GPXRouteImporterTests {

   // MARK: - Fixtures

   /// Points ~111 m apart along a meridian, so distances are predictable.
   private func gpx(track points: [(lat: Double, lon: Double, ele: Double?)], name: String? = nil) -> Data {
      let nameTag = name.map { "<name>\($0)</name>" } ?? ""
      let trkpts = points.map { point in
         let ele = point.ele.map { "<ele>\($0)</ele>" } ?? ""
         return #"<trkpt lat="\#(point.lat)" lon="\#(point.lon)">\#(ele)</trkpt>"#
      }.joined()

      return Data("""
      <?xml version="1.0" encoding="UTF-8"?>
      <gpx version="1.1" creator="test">
         <trk>\(nameTag)<trkseg>\(trkpts)</trkseg></trk>
      </gpx>
      """.utf8)
   }

   /// A straight run north: each 0.001° of latitude is ~111 m of road.
   private func northTrack(count: Int, ele: (Int) -> Double?) -> [(lat: Double, lon: Double, ele: Double?)] {
      (0..<count).map { (37.0 + Double($0) * 0.001, -122.0, ele($0)) }
   }

   // MARK: - With Elevation

   @Test func aTrackWithElevationBecomesAProfiledRoute() throws {
      // 3 km climbing 11 m per point ≈ 10%: the profile and its climb arrive
      // straight from the file, no network step.
      let data = gpx(track: northTrack(count: 28) { Double(100 + $0 * 11) }, name: "Col du Test")

      let route = try GPXRouteImporter.route(from: data)

      #expect(route.source == .gpx)
      #expect(route.name == "Col du Test")
      #expect(route.coordinates.count == 28)
      #expect(route.hasElevationProfile)
      #expect(!route.climbs.isEmpty)
      #expect(abs(route.distance - 27 * 111.32) < 30)
      #expect(route.expectedTravelTime > 0)
   }

   @Test func rteptIsAsGoodAsTrkpt() throws {
      // Planning tools export <rtept>; the rider should not care.
      let data = Data("""
      <gpx><rte>
         <rtept lat="37.000" lon="-122.0"><ele>100</ele></rtept>
         <rtept lat="37.001" lon="-122.0"><ele>105</ele></rtept>
         <rtept lat="37.002" lon="-122.0"><ele>110</ele></rtept>
      </rte></gpx>
      """.utf8)

      let route = try GPXRouteImporter.route(from: data)
      #expect(route.coordinates.count == 3)
      #expect(route.hasElevationProfile)
   }

   // MARK: - Without Elevation

   @Test func aBareTrackImportsWithoutAProfile() throws {
      let data = gpx(track: northTrack(count: 10) { _ in nil })

      let route = try GPXRouteImporter.route(from: data)

      #expect(route.source == .gpx)
      #expect(route.coordinates.count == 10)
      #expect(!route.hasElevationProfile)
      #expect(route.climbs.isEmpty)
   }

   @Test func partialElevationCountsAsNone() throws {
      // Heights on half the points cannot line up against the coordinates;
      // misaligned climbs are worse than waiting for Open-Meteo.
      let data = gpx(track: northTrack(count: 10) { $0 % 2 == 0 ? 100 : nil })

      let route = try GPXRouteImporter.route(from: data)
      #expect(!route.hasElevationProfile)
   }

   // MARK: - Failures

   @Test func garbageIsUnreadable() {
      #expect(throws: GPXRouteImporter.Failure.unreadable) {
         _ = try GPXRouteImporter.route(from: Data("not xml at all".utf8))
      }
   }

   @Test func aSinglePointIsNoTrack() {
      let data = gpx(track: northTrack(count: 1) { _ in 100 })

      #expect(throws: GPXRouteImporter.Failure.noTrack) {
         _ = try GPXRouteImporter.route(from: data)
      }
   }

   @Test func aWaypointOnlyFileIsNoTrack() {
      let data = Data("""
      <gpx><wpt lat="37.0" lon="-122.0"><name>Cafe</name></wpt></gpx>
      """.utf8)

      #expect(throws: GPXRouteImporter.Failure.noTrack) {
         _ = try GPXRouteImporter.route(from: data)
      }
   }
}
