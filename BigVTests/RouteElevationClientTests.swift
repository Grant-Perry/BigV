//
//  RouteElevationClientTests.swift
//  BigVTests
//

import CoreLocation
import Foundation
import Testing
@testable import BigV

/// Exercises the Open-Meteo client against a scripted `URLProtocol`, so the
/// request shape and every failure path are provable with no network.
///
/// Serialized because the stub protocol's script is static state — `URLProtocol`
/// instantiates the class itself, leaving nowhere per-instance to put it.
@Suite(.serialized)
struct RouteElevationClientTests {

   // MARK: - Scripted Transport

   /// One scripted answer per session. State lives in a static because
   /// `URLProtocol` instantiates the class itself; each test builds a fresh
   /// script and a fresh session around it.
   nonisolated final class ElevationStubProtocol: URLProtocol {

      nonisolated(unsafe) static var statusCode = 200
      nonisolated(unsafe) static var body = Data()
      nonisolated(unsafe) static var lastURL: URL?

      override class func canInit(with request: URLRequest) -> Bool { true }

      override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

      override func startLoading() {
         Self.lastURL = request.url

         let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: nil
         )!

         client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
         client?.urlProtocol(self, didLoad: Self.body)
         client?.urlProtocolDidFinishLoading(self)
      }

      override func stopLoading() {}
   }

   private func makeClient(status: Int = 200, body: String) -> RouteElevationClient {
      ElevationStubProtocol.statusCode = status
      ElevationStubProtocol.body = Data(body.utf8)
      ElevationStubProtocol.lastURL = nil

      let configuration = URLSessionConfiguration.ephemeral
      configuration.protocolClasses = [ElevationStubProtocol.self]
      return RouteElevationClient(session: URLSession(configuration: configuration))
   }

   private var coordinates: [CLLocationCoordinate2D] {
      [
         CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
         CLLocationCoordinate2D(latitude: 37.3360, longitude: -122.0100)
      ]
   }

   // MARK: - Success

   @Test func elevationsComeBackInOrder() async throws {
      let client = makeClient(body: #"{"elevation":[120.5,133.0]}"#)

      let elevations = try await client.elevations(for: coordinates)
      #expect(elevations == [120.5, 133.0])
   }

   @Test func theRequestCarriesEveryCoordinateAtFiveDecimals() async throws {
      let client = makeClient(body: #"{"elevation":[1,2]}"#)
      _ = try await client.elevations(for: coordinates)

      let url = try #require(ElevationStubProtocol.lastURL)
      let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)

      #expect(url.host() == "api.open-meteo.com")
      #expect(query.first { $0.name == "latitude" }?.value == "37.33490,37.33600")
      #expect(query.first { $0.name == "longitude" }?.value == "-122.00900,-122.01000")
   }

   @Test func anEmptyBatchNeverTouchesTheNetwork() async throws {
      let client = makeClient(body: "")

      let elevations = try await client.elevations(for: [])
      #expect(elevations.isEmpty)
      #expect(ElevationStubProtocol.lastURL == nil)
   }

   // MARK: - Failures

   @Test func aNon200AnswerIsABadResponse() async {
      let client = makeClient(status: 429, body: "")

      await #expect(throws: RouteElevationClientFailure.badResponse) {
         _ = try await client.elevations(for: coordinates)
      }
   }

   @Test func aShortAnswerIsRejectedNotMisaligned() async {
      // One height for two coordinates would shift every altitude after the
      // gap; the client must refuse it outright.
      let client = makeClient(body: #"{"elevation":[120.5]}"#)

      await #expect(throws: RouteElevationClientFailure.mismatchedCount) {
         _ = try await client.elevations(for: coordinates)
      }
   }

   @Test func garbageJSONThrows() async {
      let client = makeClient(body: "not json")

      await #expect(throws: (any Error).self) {
         _ = try await client.elevations(for: coordinates)
      }
   }
}
