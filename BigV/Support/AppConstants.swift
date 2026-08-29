//
//  AppConstants.swift
//  BigV
//

import Foundation

/// App-level strings that are not ride data: version, build, attribution.
enum AppConstants {

   nonisolated static var appMarketingVersion: String {
      Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
   }

   nonisolated static var appBuildNumber: String {
      Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
   }

   nonisolated static var appVersionLine: String {
      "Version \(appMarketingVersion) (\(appBuildNumber))"
   }

   nonisolated static var copyrightLine: String {
      let year = Calendar.current.component(.year, from: .now)
      return "Copyright © \(year) Cre8vPlanet Studios, LLC. - All rights reserved."
   }

   /// One line for surfaces with no vertical room to spare — the cockpit.
   nonisolated static var compactFooterLine: String {
      let year = Calendar.current.component(.year, from: .now)
      return "v\(appMarketingVersion) (\(appBuildNumber)) · © \(year) Cre8vPlanet Studios, LLC."
   }

   /// Two-line footer: marketing version + build, then copyright.
   nonisolated static var versionAndCopyrightFooter: String {
      "\(appVersionLine)\n\(copyrightLine)"
   }
}
