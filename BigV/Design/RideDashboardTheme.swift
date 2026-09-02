//
//  RideDashboardTheme.swift
//  BigV
//

import SwiftUI

/// The phone cockpit: night graphite, ice instrument light, M-division ember.
///
/// The palette itself lives in `RideChromeTokens`, which the Watch shares. What
/// stays here is everything the phone alone needs — shape metrics and the
/// trail-plate art catalog.
enum RideDashboardTheme {

   // MARK: - Atmosphere

   static let void = RideChromeTokens.void
   static let graphite = RideChromeTokens.graphite
   static let midnight = RideChromeTokens.midnight

   // MARK: - Accents

   /// Ice-blue instrument light. Used for live speed and locked GPS.
   static let ice = RideChromeTokens.ice

   /// Refined M-division amber. Replaces flat system orange on chrome.
   static let ember = RideChromeTokens.ember

   static let amber = RideChromeTokens.amber

   // MARK: - Controls

   static let go = RideChromeTokens.go
   static let halt = RideChromeTokens.halt
   static let pause = ember

   // MARK: - Vitals

   /// Heart rate, once a Watch or strap is feeding one.
   static let pulse = RideChromeTokens.pulse

   // MARK: - Compass

   /// The BigMetric dial, carried over whole: straw-yellow letters, a red
   /// flare on the cardinal under the needle, a faceted green arrow, and a
   /// mint degree readout.
   enum Compass {
      static let dialYellow = Color(red: 0.976, green: 0.851, blue: 0.549)
      static let boxOrange = Color(red: 0.980, green: 0.416, blue: 0.031)
      static let nearRed = Color(red: 0.925, green: 0.235, blue: 0.102)
      static let minty = Color(red: 0.596, green: 1.000, blue: 0.596)
      static let needleLight = Color(red: 0.60, green: 1.00, blue: 0.48)
      static let needleMid = Color(red: 0.16, green: 0.80, blue: 0.30)
      static let needleDark = Color(red: 0.03, green: 0.42, blue: 0.15)
   }

   // MARK: - Shape

   static let cardRadius: CGFloat = 18
   static let chromeRadius: CGFloat = 22
   static let fabSize: CGFloat = 48

   /// Night: `RideTrailRockyChute`, `RideTrailAtmosphere` (wet roots), `RideTrailPineDrop`.
   /// Day: `RideTrailSunSingletrack`, `RideTrailFireRoad`, `RideTrailMeadowFlow`.
   /// OTS sun family: `RideTrailSunOTSDawn`, `RideTrailSunOTSOlive`, `RideTrailSunOTSEmber`.
   /// Ride To: `RideTrailLupineGold`.
   static let trailPlateCatalog = [
      "RideTrailRockyChute",
      "RideTrailAtmosphere",
      "RideTrailPineDrop",
      "RideTrailSunSingletrack",
      "RideTrailFireRoad",
      "RideTrailMeadowFlow",
      "RideTrailSunOTSDawn",
      "RideTrailSunOTSOlive",
      "RideTrailSunOTSEmber",
      "RideTrailLupineGold"
   ]

   static let plateOlive = "RideTrailSunOTSOlive"
   static let plateDawn = "RideTrailSunOTSDawn"
   static let plateEmber = "RideTrailSunOTSEmber"
   static let plateLupineGold = "RideTrailLupineGold"
}
