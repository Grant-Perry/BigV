//
//  RouteGuidanceFix.swift
//  BigV
//

import CoreLocation
import Foundation

/// One rider position offered to the guidance engine.
///
/// Deliberately not a `CLLocation`. Guidance wants the *smoothed* speed the ride
/// engine already publishes rather than the raw per-sample figure Core Location
/// reports, and a plain value type is what lets the engine be driven from a test
/// without fabricating locations.
struct RouteGuidanceFix: Sendable, Equatable {

   let coordinate: CLLocationCoordinate2D

   /// Course over ground in degrees. Negative means unknown, matching
   /// `RideState.course`.
   let course: Double

   /// Smoothed ground speed in meters/second.
   let speed: Double

   let timestamp: Date

   init(
      coordinate: CLLocationCoordinate2D,
      course: Double = -1,
      speed: Double = 0,
      timestamp: Date
   ) {
      self.coordinate = coordinate
      self.course = course
      self.speed = speed
      self.timestamp = timestamp
   }

   static func == (lhs: RouteGuidanceFix, rhs: RouteGuidanceFix) -> Bool {
      lhs.coordinate.latitude == rhs.coordinate.latitude
         && lhs.coordinate.longitude == rhs.coordinate.longitude
         && lhs.course == rhs.course
         && lhs.speed == rhs.speed
         && lhs.timestamp == rhs.timestamp
   }
}
