//
//  RideCockpitMetricReadouts.swift
//  BigV
//

import Foundation

/// One card's worth of text.
struct RideCockpitMetricReadout: Equatable, Sendable {
   let value: String
   var unit: String?
}

/// Turns a metric into what its card says right now.
///
/// The one place that knows where each figure comes from — the ride, the
/// climb model, or route guidance — so the grid, the Traffic column and the
/// picker all read the same numbers. `nil` means the metric has no data yet:
/// no Watch feeding a pulse, no route to have an ETA on. A card with nothing
/// to say does not draw, and the picker does not offer it.
@MainActor
struct RideCockpitMetricReadouts {

   let rideViewModel: RideViewModel
   let rideClimbModel: RideClimbModel
   let routeGuidanceViewModel: RouteGuidanceViewModel

   func readout(for metric: RideCockpitMetric) -> RideCockpitMetricReadout? {
      switch metric {
         case .distance:
            RideCockpitMetricReadout(value: rideViewModel.distance, unit: rideViewModel.distanceUnit)

         case .rideTime:
            RideCockpitMetricReadout(value: rideViewModel.rideTime)

         case .movingTime:
            RideCockpitMetricReadout(value: rideViewModel.movingTime)

         case .averageSpeed:
            RideCockpitMetricReadout(value: rideViewModel.averageSpeed, unit: rideViewModel.speedUnit)

         case .maximumSpeed:
            RideCockpitMetricReadout(value: rideViewModel.maximumSpeed, unit: rideViewModel.speedUnit)

         case .elevationGain:
            RideCockpitMetricReadout(value: rideViewModel.elevationGain, unit: rideViewModel.elevationUnit)

         case .grade:
            RideCockpitMetricReadout(value: rideViewModel.grade, unit: rideViewModel.gradeUnit)

         case .altitude:
            RideCockpitMetricReadout(value: rideViewModel.altitude, unit: rideViewModel.elevationUnit)

         case .verticalSpeed:
            RideCockpitMetricReadout(value: rideViewModel.verticalSpeed, unit: rideViewModel.verticalSpeedUnit)

         case .heartRate:
            rideViewModel.isHeartRateActive
               ? RideCockpitMetricReadout(
                  value: rideViewModel.heartRate ?? RideFormatters.placeholder,
                  unit: rideViewModel.heartRateUnit
               )
               : nil

         case .ascentRemaining:
            rideClimbModel.routeAscentRemainingText.map {
               RideCockpitMetricReadout(value: $0, unit: rideClimbModel.elevationUnit)
            }

         case .distanceToGo:
            routeGuidanceViewModel.isActive
               ? RideCockpitMetricReadout(
                  value: routeGuidanceViewModel.distanceRemaining,
                  unit: routeGuidanceViewModel.distanceRemainingUnit
               )
               : nil

         case .arrivalTime:
            routeGuidanceViewModel.isActive
               ? RideCockpitMetricReadout(value: routeGuidanceViewModel.arrivalTime)
               : nil
      }
   }

   /// Every metric with data right now.
   var available: Set<RideCockpitMetric> {
      Set(RideCockpitMetric.allCases.filter { readout(for: $0) != nil })
   }

   /// The slots on a surface that will actually draw, in slot order.
   func visibleTiles(_ tiles: [RideCockpitMetric]) -> [RideCockpitMetric] {
      tiles.filter { readout(for: $0) != nil }
   }
}
