//
//  MapKitCyclingRoutePlanner.swift
//  BigV
//

import CoreLocation
import Foundation
import MapKit

/// Asks Apple for cycling routes and hands back provider-neutral ones.
///
/// Alternates are always requested. Apple exposes no "avoid busy streets" or
/// "avoid hills" control to third parties — those toggles are private to Apple
/// Maps — so the honest substitute is to offer every route the server ranked and
/// let the rider read the distances, the times and the advisories and decide.
///
/// This is the only type in the app that knows `MKDirections` exists.
@MainActor
final class MapKitCyclingRoutePlanner: PlannedRouteProviding {

   // MARK: - Private State

   /// Held so an abandoned request can be told to stop. `MKDirections` refuses a
   /// second calculation while one is running, so each request gets its own.
   private var directions: MKDirections?

   // MARK: - Planning

   func routes(
      from origin: CLLocationCoordinate2D,
      to destination: RouteDestination
   ) async throws(RoutePlanningFailure) -> [PlannedRoute] {
      cancel()

      let directions = MKDirections(request: Self.request(from: origin, to: destination))
      self.directions = directions

      let response: MKDirections.Response

      do {
         response = try await directions.calculate()
      } catch {
         let failure = Self.failure(for: error)
         DebugPrint(mode: .navigation, "Cycling route request failed: \(failure.rawValue) — \(error)")
         throw failure
      }

      // An empty list is the server saying it has no bike route here, which is a
      // fact about cycling coverage rather than a malfunction.
      guard !response.routes.isEmpty else {
         DebugPrint(mode: .navigation, "No cycling routes returned for \(destination.name)")
         throw .noCyclingRoute
      }

      let routes = response.routes.compactMap {
         PlannedRouteFactory.route(from: $0.plannedRouteDraft, source: .appleMaps)
      }

      guard !routes.isEmpty else { throw .failed }

      DebugPrint(
         mode: .navigation,
         "Planned \(routes.count) cycling route(s) to \(destination.name)"
      )

      return routes
   }

   func cancel() {
      directions?.cancel()
      directions = nil
   }

   // MARK: - Request

   private static func request(
      from origin: CLLocationCoordinate2D,
      to destination: RouteDestination
   ) -> MKDirections.Request {
      let request = MKDirections.Request()
      request.source = MKMapItem(location: CLLocation(coordinate: origin), address: nil)

      let destinationItem = MKMapItem(
         location: CLLocation(coordinate: destination.coordinate),
         address: nil
      )
      destinationItem.name = destination.name
      request.destination = destinationItem

      request.transportType = .cycling
      request.requestsAlternateRoutes = true

      return request
   }

   // MARK: - Error Mapping

   private static func failure(for error: any Error) -> RoutePlanningFailure {
      if RouteErrorClassifier.isOffline(error) { return .offline }

      guard let mapKitError = error as? MKError else { return .failed }

      // Both mean the router could not put a bicycle on the road network between
      // these points, which for the rider is the same answer.
      return switch mapKitError.code {
         case .directionsNotFound, .placemarkNotFound: .noCyclingRoute
         default: .failed
      }
   }
}

// MARK: - Extraction

private extension MKRoute {

   /// Reduces an Apple route to primitives. Extraction only: every judgement
   /// about what is rideable belongs to `PlannedRouteFactory`.
   var plannedRouteDraft: PlannedRouteFactory.Draft {
      PlannedRouteFactory.Draft(
         name: name,
         coordinates: polyline.plannedRouteCoordinates,
         distance: distance,
         expectedTravelTime: expectedTravelTime,
         advisories: advisoryNotices,
         maneuvers: steps.map {
            PlannedRouteFactory.ManeuverDraft(
               instruction: $0.instructions,
               notice: $0.notice,
               distance: $0.distance,
               coordinates: $0.polyline.plannedRouteCoordinates
            )
         }
      )
   }
}

private extension MKPolyline {

   var plannedRouteCoordinates: [CLLocationCoordinate2D] {
      guard pointCount > 0 else { return [] }

      var coordinates = [CLLocationCoordinate2D](
         repeating: CLLocationCoordinate2D(),
         count: pointCount
      )
      getCoordinates(&coordinates, range: NSRange(location: 0, length: pointCount))

      return coordinates
   }
}

private extension CLLocation {

   convenience init(coordinate: CLLocationCoordinate2D) {
      self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
   }
}
