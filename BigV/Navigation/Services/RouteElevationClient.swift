//
//  RouteElevationClient.swift
//  BigV
//

import CoreLocation
import Foundation

// MARK: - Providing

/// Anything that can turn coordinates into ground elevations.
///
/// The enricher speaks to this rather than to a URL so a test can hand it a
/// scripted terrain and exercise downsampling and batching with no network.
nonisolated protocol RouteElevationProviding: Sendable {

   /// Meters above sea level for each coordinate, in the same order.
   func elevations(for coordinates: [CLLocationCoordinate2D]) async throws -> [Double]
}

// MARK: - Failures

nonisolated enum RouteElevationClientFailure: Error, Equatable {
   case badResponse
   case mismatchedCount
}

// MARK: - Client

/// Asks Open-Meteo's elevation API for ground heights.
///
/// One GET per call, up to the API's 100-coordinate ceiling — batching a longer
/// route is the enricher's job, so this stays a single testable request. The
/// API needs no key; its license asks for attribution, which the climb page
/// and the route preview carry wherever profile data shows.
struct RouteElevationClient: RouteElevationProviding {

   /// Open-Meteo accepts at most this many coordinates per request.
   static let maximumBatchSize = 100

   private static let endpoint = URL(string: "https://api.open-meteo.com/v1/elevation")!

   private let session: URLSession

   init(session: URLSession = .shared) {
      self.session = session
   }

   // MARK: - Fetching

   func elevations(for coordinates: [CLLocationCoordinate2D]) async throws -> [Double] {
      guard !coordinates.isEmpty else { return [] }

      let (data, response) = try await session.data(from: Self.url(for: coordinates))

      guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
         throw RouteElevationClientFailure.badResponse
      }

      let payload = try JSONDecoder().decode(Payload.self, from: data)

      // A silently short answer would misalign every altitude after the gap,
      // which is worse than no profile at all.
      guard payload.elevation.count == coordinates.count else {
         throw RouteElevationClientFailure.mismatchedCount
      }

      return payload.elevation
   }

   // MARK: - Request

   /// Five decimal places is about 1.1 m of ground — tighter than the terrain
   /// model resolves, and it keeps a 100-point query URL comfortably short.
   private static func url(for coordinates: [CLLocationCoordinate2D]) -> URL {
      var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
      components.queryItems = [
         URLQueryItem(name: "latitude", value: list(of: coordinates.map(\.latitude))),
         URLQueryItem(name: "longitude", value: list(of: coordinates.map(\.longitude)))
      ]
      return components.url!
   }

   private static func list(of values: [Double]) -> String {
      values
         .map { String(format: "%.5f", $0) }
         .joined(separator: ",")
   }

   // MARK: - Payload

   private struct Payload: Decodable {
      let elevation: [Double]
   }
}
