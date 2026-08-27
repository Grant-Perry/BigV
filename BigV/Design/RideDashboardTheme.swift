//
//  RideDashboardTheme.swift
//  BigV
//

import SwiftUI

/// Shared cockpit tokens: night graphite, ice instrument light, M-division ember.
enum RideDashboardTheme {

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
   static let pause = ember

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
