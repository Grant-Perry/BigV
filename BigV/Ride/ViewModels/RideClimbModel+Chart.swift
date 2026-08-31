//
//  RideClimbModel+Chart.swift
//  BigV
//

import Foundation

/// A climb's footprint on the whole-route chart, in axis units.
struct RideClimbChartSpan: Identifiable, Equatable {
   let id: Int
   let label: String
   let startX: Double
   let endX: Double
}

/// The climb page's chart data: on a climb the window is that climb, base to
/// crest; between climbs it is the whole route with every climb marked.
extension RideClimbModel {

   /// The plotted profile, or `nil` when there is nothing worth drawing.
   var chartSeries: RideClimbProfileSeries? {
      let profile = routeProfile
      guard profile.count > 1, let last = profile.last else { return nil }

      let window = chartWindow(routeEnd: last.distanceAlongRoute)
      return RideClimbProfileSeriesBuilder.series(
         profile: profile,
         start: window.start,
         end: window.end,
         playheadDistance: progress.playheadDistance,
         playheadAltitude: progress.playheadAltitude,
         system: unitSystem
      )
   }

   /// Climb footprints for the whole-route view. Empty while on a climb — the
   /// window is the climb, so marking it again would just dim the hero.
   var chartClimbSpans: [RideClimbChartSpan] {
      guard progress.activeClimb == nil else { return [] }

      return routeClimbs.map { climb in
         RideClimbChartSpan(
            id: climb.id,
            label: climb.category.label,
            startX: RideClimbProfileSeriesBuilder.distanceValue(climb.startDistance, system: unitSystem),
            endX: RideClimbProfileSeriesBuilder.distanceValue(climb.endDistance, system: unitSystem)
         )
      }
   }

   /// Axis unit for the chart's footer, e.g. "MI".
   var chartDistanceUnit: String { unitSystem.distanceUnit }

   private func chartWindow(routeEnd: Double) -> (start: Double, end: Double) {
      guard let climb = progress.activeClimb else { return (0, routeEnd) }
      return (climb.startDistance, min(climb.endDistance, routeEnd))
   }
}
