//
//  RouteFavoriteSectionPreferences.swift
//  BigV
//

import Foundation

/// UserDefaults keys for the route planner favorites section chrome.
nonisolated enum RouteFavoriteSectionPreferences {

   static let expandedKey = "route.favorites.sectionExpanded"
   static let expandedDefault = true

   static func isExpanded(in defaults: UserDefaults = .standard) -> Bool {
      defaults.object(forKey: expandedKey) as? Bool ?? expandedDefault
   }

   static func setExpanded(_ isExpanded: Bool, in defaults: UserDefaults = .standard) {
      defaults.set(isExpanded, forKey: expandedKey)
   }
}
