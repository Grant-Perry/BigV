//
//  RouteRecentSectionPreferences.swift
//  BigV
//

import Foundation

/// UserDefaults keys for the route planner recents section chrome.
nonisolated enum RouteRecentSectionPreferences {

   static let expandedKey = "route.recents.sectionExpanded"
   static let expandedDefault = true

   static func isExpanded(in defaults: UserDefaults = .standard) -> Bool {
      defaults.object(forKey: expandedKey) as? Bool ?? expandedDefault
   }

   static func setExpanded(_ isExpanded: Bool, in defaults: UserDefaults = .standard) {
      defaults.set(isExpanded, forKey: expandedKey)
   }
}
