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
/// Order is what the rider reaches for, in the order they reach for it: traffic
/// is one swipe from the dashboard — the radar road at a readable size with the
/// speed, the totals and the map still in view — the full radar page is the
/// swipe after it, climb is next, and the full map is last because the drawer
/// and its expand control already get the rider there without paging.
enum RidePage: Int, CaseIterable, Identifiable, Sendable {

   case dashboard
   case traffic
   case radar
   case climb
   case map

   /// Pages that only make sense with a radar on the bike.
   var requiresRadar: Bool {
      self == .traffic || self == .radar
   }

   var id: Int { rawValue }

   /// Spoken by VoiceOver for the page indicator.
   var title: String {
      switch self {
         case .dashboard: "Dashboard"
         case .traffic: "Traffic"
         case .radar: "Radar"
         case .climb: "Climb"
         case .map: "Map"
      }
   }
}
