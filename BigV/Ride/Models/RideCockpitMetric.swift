//
//  RideCockpitMetric.swift
//  BigV
//

import Foundation

/// Every figure a cockpit card can show.
///
/// The catalog behind the long-press swap: a card is a slot, a metric is what
/// fills it, and a rider can put any of these in any slot. Speed is not here
/// on purpose — the hero is speed, always, so a speed card would be a
/// duplicate and the hero is never a slot.
///
/// Raw values are persisted, so they are stable names, not display strings.
enum RideCockpitMetric: String, CaseIterable, Codable, Sendable, Identifiable {

   case distance
   case rideTime
   case movingTime
   case averageSpeed
   case maximumSpeed
   case elevationGain
   case grade
   case altitude
   case verticalSpeed
   case heartRate
   case ascentRemaining
   case distanceToGo
   case arrivalTime

   var id: String { rawValue }

   /// The card's label, in the cockpit's own capitals.
   var title: String {
      switch self {
         case .distance: "DISTANCE"
         case .rideTime: "RIDE TIME"
         case .movingTime: "MOVING"
         case .averageSpeed: "AVG SPEED"
         case .maximumSpeed: "MAX SPEED"
         case .elevationGain: "ELEV GAIN"
         case .grade: "GRADE"
         case .altitude: "ALT"
         case .verticalSpeed: "VAM"
         case .heartRate: "HEART"
         case .ascentRemaining: "ASC LEFT"
         case .distanceToGo: "TO GO"
         case .arrivalTime: "ETA"
      }
   }

   /// How the picker names it: a sentence, not a card label.
   var menuTitle: String {
      switch self {
         case .distance: "Distance"
         case .rideTime: "Ride time"
         case .movingTime: "Moving time"
         case .averageSpeed: "Average speed"
         case .maximumSpeed: "Max speed"
         case .elevationGain: "Elevation gain"
         case .grade: "Grade"
         case .altitude: "Altitude"
         case .verticalSpeed: "VAM"
         case .heartRate: "Heart rate"
         case .ascentRemaining: "Ascent left"
         case .distanceToGo: "Distance to go"
         case .arrivalTime: "Arrival time"
      }
   }

   var symbolName: String {
      switch self {
         case .distance: "point.topleft.down.to.point.bottomright.curvepath.fill"
         case .rideTime: "stopwatch.fill"
         case .movingTime: "figure.outdoor.cycle"
         case .averageSpeed: "gauge.with.dots.needle.33percent"
         case .maximumSpeed: "gauge.with.dots.needle.100percent"
         case .elevationGain: "arrow.up.right"
         case .grade: "angle"
         case .altitude: "mountain.2.fill"
         case .verticalSpeed: "arrow.up.to.line"
         case .heartRate: "heart.fill"
         case .ascentRemaining: "arrow.up.forward.circle"
         case .distanceToGo: "flag.checkered"
         case .arrivalTime: "clock.fill"
      }
   }

   /// The identifier the UI tests already look for; it follows the metric,
   /// not the slot, so a moved card is still the same card to a test.
   var accessibilityIdentifier: String {
      switch self {
         case .distance: "ride.tile.distance"
         case .rideTime: "ride.tile.rideTime"
         case .movingTime: "ride.tile.movingTime"
         case .averageSpeed: "ride.tile.avgSpeed"
         case .maximumSpeed: "ride.tile.maxSpeed"
         case .elevationGain: "ride.tile.elevationGain"
         case .grade: "ride.tile.grade"
         case .altitude: "ride.tile.altitude"
         case .verticalSpeed: "ride.tile.vam"
         case .heartRate: "ride.tile.heartRate"
         case .ascentRemaining: "ride.tile.ascentRemaining"
         case .distanceToGo: "ride.tile.toGo"
         case .arrivalTime: "ride.tile.eta"
      }
   }

   /// The figures a cockpit must never lose. A protected card can trade
   /// places with another card, but nothing can replace it outright: the only
   /// way distance leaves a screen is if it were shown twice, and it never is.
   var isProtected: Bool {
      self == .distance || self == .rideTime
   }

   /// The live chart a tap on this card pins under the hero, if it has one.
   var chartMetric: RideLiveMetric? {
      switch self {
         case .elevationGain: .elevation
         case .averageSpeed, .maximumSpeed: .speed
         case .heartRate: .heartRate
         default: nil
      }
   }
}
