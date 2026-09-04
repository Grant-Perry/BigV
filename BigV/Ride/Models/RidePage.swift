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
/// Order is what the rider reaches for, in the order they reach for it: the
/// road behind is the one page worth a glance mid-traffic, so it sits one swipe
/// from the dashboard. The map is the page they read at a junction, and the
/// climb profile is the page they study, so it sits furthest out.
enum RidePage: Int, CaseIterable, Identifiable, Sendable {

   case dashboard
   case radar
   case map
   case climb

   var id: Int { rawValue }

   /// Spoken by VoiceOver for the page indicator.
   var title: String {
      switch self {
         case .dashboard: "Dashboard"
         case .radar: "Radar"
         case .map: "Map"
         case .climb: "Climb"
      }
   }
}
