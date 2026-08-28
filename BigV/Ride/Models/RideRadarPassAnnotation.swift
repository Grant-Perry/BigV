//
//  RideRadarPassAnnotation.swift
//  BigV
//

import CoreLocation
import Foundation

/// One radar pass placed on a saved ride's map.
///
/// A display projection of `RideRadarEvent`, carrying only what the map needs:
/// where the rider was and how bad the pass got.
struct RideRadarPassAnnotation: Identifiable, Sendable, Equatable {

   let id: Int
   let latitude: Double
   let longitude: Double
   let tier: RideRadarThreatTier

   var coordinate: CLLocationCoordinate2D {
      CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
   }
}
