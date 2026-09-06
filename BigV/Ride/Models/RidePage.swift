//
//  RidePage.swift
//  BigV
//

import Foundation

/// The horizontally swipeable pages of the live ride screen.
///
/// Declaration order is swipe order, and the first case is the landing page. New
/// pages (stats, weather) are added here and nowhere else.
///
/// Order is what the rider reaches for, in the order they reach for it: radar is
/// one swipe from the dashboard, climb is next, and the full map is last because
/// the drawer and its expand control already get the rider there without paging.
enum RidePage: Int, CaseIterable, Identifiable, Sendable {

   case dashboard
   case radar
   case climb
   case map

   var id: Int { rawValue }

   /// Spoken by VoiceOver for the page indicator.
   var title: String {
      switch self {
         case .dashboard: "Dashboard"
         case .radar: "Radar"
         case .climb: "Climb"
         case .map: "Map"
      }
   }
}
