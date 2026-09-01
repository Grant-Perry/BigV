//
//  RideGPXExporterTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

struct RideGPXExporterTests {

   @Test func twoPointsBecomeATrack() throws {
      let start = Date(timeIntervalSince1970: 1_700_000_000)
      let points = [
         RideGPXExporter.Point(timestamp: start, latitude: 37.1, longitude: -122.2, altitude: 12),
         RideGPXExporter.Point(
            timestamp: start.addingTimeInterval(30),
            latitude: 37.2,
            longitude: -122.3,
            altitude: 18
         )
      ]

      let xml = String(
         decoding: try RideGPXExporter.data(name: "Morning Loop", startDate: start, points: points),
         as: UTF8.self
      )

      #expect(xml.contains("<gpx version=\"1.1\" creator=\"BigVelo\""))
      #expect(xml.contains("<name>Morning Loop</name>"))
      #expect(xml.contains("lat=\"37.100000\""))
      #expect(xml.contains("lon=\"-122.200000\""))
      #expect(xml.contains("<ele>12.000000</ele>"))
      #expect(xml.contains("<time>"))
   }

   @Test func aSinglePointIsNotATrack() {
      let start = Date(timeIntervalSince1970: 1_700_000_000)
      let points = [
         RideGPXExporter.Point(timestamp: start, latitude: 37, longitude: -122, altitude: 0)
      ]

      #expect(throws: RideGPXExporter.Failure.noTrack) {
         _ = try RideGPXExporter.data(name: "Short", startDate: start, points: points)
      }
   }

   @Test func namesEscapeMarkup() throws {
      let start = Date(timeIntervalSince1970: 1_700_000_000)
      let points = [
         RideGPXExporter.Point(timestamp: start, latitude: 1, longitude: 2, altitude: 3),
         RideGPXExporter.Point(timestamp: start.addingTimeInterval(1), latitude: 1.1, longitude: 2.1, altitude: 4)
      ]

      let xml = String(
         decoding: try RideGPXExporter.data(name: "Tom & Jerry <ride>", startDate: start, points: points),
         as: UTF8.self
      )

      #expect(xml.contains("Tom &amp; Jerry &lt;ride&gt;"))
      #expect(!xml.contains("Tom & Jerry"))
   }
}
