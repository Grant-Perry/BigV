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
