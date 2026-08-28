//
//  RideChromeTokens.swift
//  BigVShared
//

import SwiftUI

/// The raw cockpit palette, shared by the phone dashboard and the Watch glance.
///
/// Lives here rather than in `RideDashboardTheme` so the Watch can wear the same
/// instrument light without also inheriting the phone's trail-plate art catalog,
/// which is wrong for a 45 mm screen and costs battery to composite.
nonisolated enum RideChromeTokens {

   // MARK: - Atmosphere

   static let void = Color(red: 0.015, green: 0.016, blue: 0.020)
   static let graphite = Color(red: 0.075, green: 0.082, blue: 0.098)
   static let midnight = Color(red: 0.040, green: 0.070, blue: 0.130)

   // MARK: - Accents

   /// Ice-blue instrument light. Used for live speed and locked GPS.
   static let ice = Color(red: 0.58, green: 0.84, blue: 0.96)

   /// Refined M-division amber. Replaces flat system orange on chrome.
   static let ember = Color(red: 1.00, green: 0.48, blue: 0.12)

   static let amber = Color(red: 1.00, green: 0.62, blue: 0.22)

   // MARK: - Controls

   static let go = Color(red: 0.16, green: 0.78, blue: 0.36)
   static let halt = Color(red: 0.90, green: 0.18, blue: 0.20)

   // MARK: - Vitals

   /// Heart rate. Warm enough to read as a pulse, not as an alarm.
   static let pulse = Color(red: 0.98, green: 0.28, blue: 0.36)
}
