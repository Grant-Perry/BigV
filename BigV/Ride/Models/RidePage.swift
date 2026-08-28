//
//  RidePage.swift
//  BigV
//

import Foundation

/// The horizontally swipeable pages of the live ride screen.
///
/// Declaration order is swipe order, and the first case is the landing page. New
/// pages (climb, stats, weather) are added here and nowhere else.
enum RidePage: Int, CaseIterable, Identifiable, Sendable {

   case dashboard
   case map
   case radar

   var id: Int { rawValue }

   /// Spoken by VoiceOver for the page indicator.
   var title: String {
      switch self {
         case .dashboard: "Dashboard"
         case .map: "Map"
         case .radar: "Radar"
      }
   }
}
