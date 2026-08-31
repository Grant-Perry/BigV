//
//  GPXRouteImporter.swift
//  BigV
//

import CoreLocation
import Foundation

/// Reads a GPX file into a `PlannedRoute`.
///
/// One-shot import, not a course library: the rider picks a file, previews it,
/// rides it. Both `trkpt` (a recorded track) and `rtept` (a planned route) are
/// accepted, because tools export either and the rider should not need to know
/// which. `<ele>` values pass straight through as the profile — a GPX with
/// altitudes never touches the network — while a bare one is enriched like any
/// Apple route.
///
/// GPX carries no travel-time estimate, so a modest touring pace stands in;
/// preview and ETA need *some* number, and an honest guess beats "1 min".
nonisolated enum GPXRouteImporter {

   // MARK: - Failures

   enum Failure: Error, Equatable {
      /// The file is not XML a GPX parser can read.
      case unreadable

      /// Parsed fine but held fewer than two usable points.
      case noTrack
   }

   /// ~16 km/h — a touring pace for the stand-in time estimate.
   private static let assumedPace: Double = 4.5

   // MARK: - Import

   static func route(from data: Data, id: UUID = UUID()) throws(Failure) -> PlannedRoute {
      let reader = Reader()
      let parser = XMLParser(data: data)
      parser.delegate = reader

      guard parser.parse() || !reader.points.isEmpty else { throw .unreadable }
      guard reader.points.count > 1 else { throw .noTrack }

      // Altitudes only count when every point carried one; a partial set
      // cannot line up against the coordinates.
      let altitudes = reader.points.allSatisfy { $0.elevation != nil }
         ? reader.points.compactMap(\.elevation)
         : []

      let coordinates = reader.points.map(\.coordinate)
      let length = zip(coordinates, coordinates.dropFirst()).reduce(0.0) {
         $0 + RideRouteDownsampler.meters(from: $1.0, to: $1.1)
      }

      let draft = PlannedRouteFactory.Draft(
         name: reader.name ?? "",
         coordinates: coordinates,
         distance: length,
         expectedTravelTime: length / assumedPace,
         altitudes: altitudes
      )

      guard let route = PlannedRouteFactory.route(from: draft, source: .gpx, id: id) else {
         throw .noTrack
      }

      return route
   }

   // MARK: - Reader

   /// SAX delegate collecting points as the parser streams them, so a
   /// multi-megabyte track never materializes as a DOM.
   private final class Reader: NSObject, XMLParserDelegate {

      struct Point {
         let coordinate: CLLocationCoordinate2D
         var elevation: Double?
      }

      var points: [Point] = []
      var name: String?

      private var isInsidePoint = false
      private var isReadingElevation = false
      private var isReadingName = false
      private var elevationText = ""
      private var nameText = ""

      /// Only the first `<name>` in the file — the track or route title, not a
      /// waypoint's.
      private var hasCapturedName = false

      func parser(
         _ parser: XMLParser,
         didStartElement elementName: String,
         namespaceURI: String?,
         qualifiedName: String?,
         attributes: [String: String]
      ) {
         switch elementName {
            case "trkpt", "rtept":
               guard let latitude = Double(attributes["lat"] ?? ""),
                     let longitude = Double(attributes["lon"] ?? "")
               else { return }

               points.append(
                  Point(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
               )
               isInsidePoint = true

            case "ele" where isInsidePoint:
               isReadingElevation = true
               elevationText = ""

            case "name" where !hasCapturedName && !isInsidePoint:
               isReadingName = true
               nameText = ""

            default:
               break
         }
      }

      func parser(_ parser: XMLParser, foundCharacters string: String) {
         if isReadingElevation { elevationText += string }
         if isReadingName { nameText += string }
      }

      func parser(
         _ parser: XMLParser,
         didEndElement elementName: String,
         namespaceURI: String?,
         qualifiedName: String?
      ) {
         switch elementName {
            case "trkpt", "rtept":
               isInsidePoint = false

            case "ele" where isReadingElevation:
               isReadingElevation = false
               if let elevation = Double(elevationText.trimmingCharacters(in: .whitespacesAndNewlines)),
                  !points.isEmpty {
                  points[points.count - 1].elevation = elevation
               }

            case "name" where isReadingName:
               isReadingName = false
               hasCapturedName = true
               let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
               name = trimmed.isEmpty ? nil : trimmed

            default:
               break
         }
      }
   }
}
