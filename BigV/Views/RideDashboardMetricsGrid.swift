//
//  RideDashboardMetricsGrid.swift
//  BigV
//

import SwiftUI

/// Everything under the hero, in whatever order the rider has put it.
///
/// The cards come from the cockpit layout, not from a list here. Portrait
/// leads with the first two slots at full size — distance and ride time until
/// the rider says otherwise — then runs the rest three across. AVG and MAX
/// ride in the hero there unless they have been given a card. Landscape has
/// no corner chips, so it carries the whole set in compact tiles, AVG and MAX
/// included.
///
/// A slot whose metric has no data right now — no Watch, no route — does not
/// draw, the same way those tiles always came and went.
struct RideDashboardMetricsGrid: View {

   enum Layout: Sendable {
      case portrait
      case landscape
   }

   let rideViewModel: RideViewModel
   let routeGuidanceViewModel: RouteGuidanceViewModel
   var layout: Layout = .portrait

   @Environment(RideClimbModel.self) private var rideClimbModel

   private var tileColumns: [GridItem] {
      Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
   }

   private var readouts: RideCockpitMetricReadouts {
      RideCockpitMetricReadouts(
         rideViewModel: rideViewModel,
         rideClimbModel: rideClimbModel,
         routeGuidanceViewModel: routeGuidanceViewModel
      )
   }

   /// Where AVG and MAX land in landscape when they have no card of their
   /// own: after the totals and the climb pair, where they always sat.
   private static let landscapeSpeedSlot = 4

   /// The slots that will draw, in slot order.
   private var visibleTiles: [RideCockpitMetric] {
      var tiles = rideViewModel.cockpitLayout.dashboardTiles

      if layout == .landscape {
         let extras = [RideCockpitMetric.averageSpeed, .maximumSpeed].filter { !tiles.contains($0) }
         tiles.insert(contentsOf: extras, at: min(Self.landscapeSpeedSlot, tiles.count))
      }

      return readouts.visibleTiles(tiles)
   }

   /// Portrait's big pair: the first two visible slots.
   private var leadTiles: [RideCockpitMetric] {
      layout == .portrait ? Array(visibleTiles.prefix(2)) : []
   }

   private var gridTiles: [RideCockpitMetric] {
      Array(visibleTiles.dropFirst(leadTiles.count))
   }

   var body: some View {
      let readouts = readouts

      VStack(spacing: 10) {
         if !leadTiles.isEmpty {
            HStack(spacing: 10) {
               ForEach(Array(leadTiles.enumerated()), id: \.element) { index, metric in
                  card(
                     for: metric,
                     readouts: readouts,
                     isCompact: false,
                     gutterAlignment: index == 0 ? .trailing : .leading
                  )
               }
            }
         }

         LazyVGrid(columns: tileColumns, spacing: 10) {
            ForEach(gridTiles) { metric in
               card(for: metric, readouts: readouts, isCompact: true)
            }
         }
      }
      .animation(.easeInOut(duration: 0.25), value: visibleTiles)
   }

   // MARK: - Cards

   @ViewBuilder
   private func card(
      for metric: RideCockpitMetric,
      readouts: RideCockpitMetricReadouts,
      isCompact: Bool,
      gutterAlignment: HorizontalAlignment = .leading
   ) -> some View {
      let readout = readouts.readout(for: metric)
      let onLongPress = { rideViewModel.requestMetricSwap(metric, on: .dashboard) }

      if metric == .heartRate {
         RideHeartRateMetricTile(
            value: readout?.value ?? RideFormatters.placeholder,
            unit: readout?.unit ?? rideViewModel.heartRateUnit,
            beatsPerMinute: rideViewModel.heartRateBeatsPerMinute,
            isSelected: rideViewModel.selectedMetric == .heartRate,
            isCompact: isCompact,
            action: { rideViewModel.selectMetric(.heartRate) },
            onLongPress: onLongPress
         )
      } else {
         RideMetricTile(
            title: metric.title,
            value: readout?.value ?? RideFormatters.placeholder,
            unit: readout?.unit,
            identifier: metric.accessibilityIdentifier,
            gutterAlignment: gutterAlignment,
            action: metric.chartMetric.map { chart in { rideViewModel.selectMetric(chart) } },
            isSelected: metric.chartMetric.map { rideViewModel.selectedMetric == $0 } ?? false,
            isCompact: isCompact,
            onLongPress: onLongPress
         )
      }
   }
}
