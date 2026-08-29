//
//  RideTab.swift
//  BigV
//

import Foundation

/// The app's top-level destinations, in tab-bar order.
///
/// Distinct from `RidePage`: a tab is where the rider is in the app, a page is
/// which face of the cockpit they swiped to inside the dashboard tab.
enum RideTab: Int, CaseIterable, Identifiable, Sendable {

   case dashboard
   case rides
   case route
   case settings

   var id: Int { rawValue }

   var title: String {
      switch self {
         case .dashboard: "Dashboard"
         case .rides: "Rides"
         case .route: "Route"
         case .settings: "Settings"
      }
   }

   var symbolName: String {
      switch self {
         case .dashboard: "gauge.open.with.lines.needle.33percent"
         case .rides: "clock.arrow.circlepath"
         case .route: "magnifyingglass"
         case .settings: "gearshape.fill"
      }
   }
}
