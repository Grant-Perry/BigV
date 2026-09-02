//
//  RideDashboardTheme.swift
//  BigV
//

import SwiftUI

/// The phone cockpit: night graphite, ice instrument light, M-division ember —
/// and, for the sun, a day face of paper and ink.
///
/// The night palette lives in `RideChromeTokens`, which the Watch shares. Every
/// colour here resolves against the current colour scheme, so a view that
/// asks for `ink` gets white at night and near-black by day without knowing
/// which it is on. What else stays here is what the phone alone needs — shape
/// metrics and the trail-plate art catalog.
enum RideDashboardTheme {

   // MARK: - Atmosphere

   /// The ground. Near-black at night, warm paper by day.
   static let void = dynamic(dark: RideChromeTokens.void, light: Color(red: 0.965, green: 0.962, blue: 0.950))
   static let graphite = dynamic(dark: RideChromeTokens.graphite, light: Color(red: 0.895, green: 0.900, blue: 0.905))
   static let midnight = dynamic(dark: RideChromeTokens.midnight, light: Color(red: 0.845, green: 0.885, blue: 0.945))

   // MARK: - Ink

   /// Text and glyphs at full strength. White on graphite, black on paper.
   static let ink = dynamic(dark: .white, light: lightInk)

   /// Ink at a given night strength.
   ///
   /// Night keeps the level as drawn. Day pushes it up: a reflective screen
   /// in sunlight loses contrast before anything else, so a caption that is
   /// fine at 45 % white on graphite needs closer to 65 % black on paper to
   /// survive the same glare. Hairlines below 20 % scale rather than shift so
   /// a card edge stays an edge and never becomes a rule.
   static func ink(_ level: Double) -> Color {
      dynamic(
         dark: UIColor(white: 1, alpha: level),
         light: UIColor(lightInk).withAlphaComponent(dayLevel(level))
      )
   }

   /// A scrim that settles photos and maps under text: black at night, paper
   /// by day, so a veil always pulls the picture toward the ground it sits on.
   static func veil(_ level: Double) -> Color {
      dynamic(
         dark: UIColor(white: 0, alpha: level),
         light: UIColor(white: 1, alpha: dayLevel(level))
      )
   }

   private static let lightInk = Color(red: 0.055, green: 0.065, blue: 0.085)

   private static func dayLevel(_ level: Double) -> Double {
      level < 0.2 ? min(1, level * 1.5) : min(1, level + 0.2)
   }

   // MARK: - Accents

   /// Ice-blue instrument light. Used for live speed and locked GPS. Day
   /// deepens it to a sky blue that still reads on paper.
   static let ice = dynamic(dark: RideChromeTokens.ice, light: Color(red: 0.03, green: 0.40, blue: 0.66))

   /// Refined M-division amber. Replaces flat system orange on chrome.
   static let ember = dynamic(dark: RideChromeTokens.ember, light: Color(red: 0.84, green: 0.34, blue: 0.02))

   static let amber = dynamic(dark: RideChromeTokens.amber, light: Color(red: 0.78, green: 0.42, blue: 0.00))

   // MARK: - Controls

   static let go = dynamic(dark: RideChromeTokens.go, light: Color(red: 0.05, green: 0.56, blue: 0.24))
   static let halt = dynamic(dark: RideChromeTokens.halt, light: Color(red: 0.80, green: 0.10, blue: 0.13))
   static let pause = ember

   // MARK: - Vitals

   /// Heart rate, once a Watch or strap is feeding one.
   static let pulse = dynamic(dark: RideChromeTokens.pulse, light: Color(red: 0.84, green: 0.14, blue: 0.24))

   // MARK: - Compass

   /// The BigMetric dial, carried over whole: straw-yellow letters, a red
   /// flare on the cardinal under the needle, a faceted green arrow, and a
   /// mint degree readout. By day the straw and mint drop to ochre and pine
   /// so the letters hold on paper.
   enum Compass {
      static let dialYellow = dynamic(dark: Color(red: 0.976, green: 0.851, blue: 0.549), light: Color(red: 0.52, green: 0.37, blue: 0.03))
      static let boxOrange = dynamic(dark: Color(red: 0.980, green: 0.416, blue: 0.031), light: Color(red: 0.86, green: 0.34, blue: 0.00))
      static let nearRed = Color(red: 0.925, green: 0.235, blue: 0.102)
      static let minty = dynamic(dark: Color(red: 0.596, green: 1.000, blue: 0.596), light: Color(red: 0.03, green: 0.46, blue: 0.22))
      static let needleLight = dynamic(dark: Color(red: 0.60, green: 1.00, blue: 0.48), light: Color(red: 0.36, green: 0.82, blue: 0.34))
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

   // MARK: - Resolution

   /// One colour that answers to the trait collection, so `.opacity`,
   /// gradients and `.shadow` all stay scheme-aware for free.
   static func dynamic(dark: Color, light: Color) -> Color {
      dynamic(dark: UIColor(dark), light: UIColor(light))
   }

   static func dynamic(dark: UIColor, light: UIColor) -> Color {
      Color(uiColor: UIColor { traits in
         traits.userInterfaceStyle == .dark ? dark : light
      })
   }
}
