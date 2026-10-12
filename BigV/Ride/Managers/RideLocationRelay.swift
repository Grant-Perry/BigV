//
//  RideLocationRelay.swift
//  BigV
//

import CoreLocation
import Foundation

/// Turns `CLLocationManagerDelegate` callbacks into an ordered stream the main
/// actor consumes, without making `RideLocationManager` an `NSObject` or
/// assuming which thread Core Location called back on.
///
/// One relay outlives every receiver: the manager swaps `CLLocationManager`
/// instances between rides, and each new one is pointed at this same object.
final class RideLocationRelay: NSObject, CLLocationManagerDelegate, Sendable {

   enum Signal: Sendable {
      case locations([CLLocation])
      case failed(any Error)
      case authorizationChanged
      case pausedBySystem
   }

   let signals: AsyncStream<Signal>
   private let continuation: AsyncStream<Signal>.Continuation

   override init() {
      (signals, continuation) = AsyncStream<Signal>.makeStream(bufferingPolicy: .unbounded)
      super.init()
   }

   nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
      continuation.yield(.locations(locations))
   }

   nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
      continuation.yield(.failed(error))
   }

   nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
      continuation.yield(.authorizationChanged)
   }

   nonisolated func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
      continuation.yield(.pausedBySystem)
   }
}
