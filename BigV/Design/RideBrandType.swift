//
//  RideBrandType.swift
//  BigV
//

import SwiftUI

/// The marketing lockup face — Outfit ExtraBold, bundled next to this file.
///
/// PostScript name is `Outfit-ExtraBold`. Register the TTF in `UIAppFonts`
/// or SwiftUI falls back to a system rounded that is not the site.
enum RideBrandType {

   static let displayName = "Outfit-ExtraBold"

   static func display(_ size: CGFloat) -> Font {
      .custom(displayName, size: size)
   }
}
