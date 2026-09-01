//
//  RideGPXExporter.swift
//  BigV
//

import Foundation

/// Writes a recorded ride as GPX 1.1 so other apps can open the track.
nonisolated enum RideGPXExporter {

   enum Failure: Error, Equatable {
      case noTrack
   }

   struct Point: Sendable {
      let timestamp: Date
      let latitude: Double
      let longitude: Double
      let altitude: Double
   }

   static func data(
      name: String,
      startDate: Date,
      points: [Point]
   ) throws(Failure) -> Data {
      guard points.count >= 2 else { throw .noTrack }

      let iso = ISO8601DateFormatter()
      iso.formatOptions = [.withInternetDateTime]

      let trackPoints = points.map { point in
         """
               <trkpt lat="\(gpxNumber(point.latitude))" lon="\(gpxNumber(point.longitude))">
                  <ele>\(gpxNumber(point.altitude))</ele>
                  <time>\(iso.string(from: point.timestamp))</time>
               </trkpt>
         """
      }.joined(separator: "\n")

      let xml = """
      <?xml version="1.0" encoding="UTF-8"?>
      <gpx version="1.1" creator="BigVelo" xmlns="http://www.topografix.com/GPX/1/1">
         <metadata>
            <name>\(escaped(name))</name>
            <time>\(iso.string(from: startDate))</time>
         </metadata>
         <trk>
            <name>\(escaped(name))</name>
            <trkseg>
      \(trackPoints)
            </trkseg>
         </trk>
      </gpx>
      """

      return Data(xml.utf8)
   }

   static func fileName(startDate: Date) -> String {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
      formatter.dateFormat = "yyyy-MM-dd"
      return "BigVelo-\(formatter.string(from: startDate)).gpx"
   }

   // MARK: - Private

   private static func gpxNumber(_ value: Double) -> String {
      String(format: "%.6f", value)
   }

   private static func escaped(_ raw: String) -> String {
      raw
         .replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
   }
}
