//
//  RideWordmark.swift
//  BigV
//

import SwiftUI

/// Site lockup: Outfit ExtraBold, cream → copper. Block shade is splash-only.
struct RideWordmark: View {

   enum Chrome {
      /// Gradient face only — settings, paywall, any lockup that is not the splash.
      case face
      /// Site hero: hard extrusion plus the soft ground drop.
      case splash
   }

   var pointSize: CGFloat = 72
   var chrome: Chrome = .face

   var body: some View {
      ZStack {
         if chrome == .splash {
            splashShade
         }

         lockup
            .foregroundStyle(Self.goldWash)
      }
      .padding(.bottom, chrome == .splash ? pointSize * 0.16 : 2)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("BigVelo")
   }

   // MARK: - Face

   private var lockup: Text {
      Text("BigVelo")
         .font(RideBrandType.display(pointSize))
         .tracking(pointSize * -0.07)
   }

   /// Site `#wordmarkFace`: `#fff8e6 → #feeab5 → #d4a66a → #e07a3a`.
   static let goldWash = LinearGradient(
      stops: [
         .init(color: Self.hex(0xFFF8E6), location: 0.06),
         .init(color: Self.hex(0xFEEAB5), location: 0.36),
         .init(color: Self.hex(0xD4A66A), location: 0.68),
         .init(color: Self.hex(0xE07A3A), location: 1.00)
      ],
      startPoint: .top,
      endPoint: .bottom
   )

   // MARK: - Splash shade

   /// Stacked copies make a hard block, not a blur. Offset matches the site
   /// shade (`8px` SVG + `8px` CSS on a `142px` face ≈ `0.11em` down).
   private var splashShade: some View {
      let steps = max(7, Int((pointSize * 0.12).rounded()))
      return ZStack {
         ForEach(1...steps, id: \.self) { step in
            lockup
               .foregroundStyle(Self.extrusion)
               .offset(
                  x: CGFloat(step) * 0.32,
                  y: CGFloat(step) * 0.92
               )
         }
      }
      .shadow(color: .black.opacity(0.45), radius: pointSize * 0.35, y: pointSize * 0.25)
   }

   /// Site shade floor `#84493d`, pushed darker so the block reads on trail video.
   private static let extrusion = Self.hex(0x2A1B12).opacity(0.92)

   // MARK: - Hex

   private static func hex(_ rgb: UInt32) -> Color {
      Color(
         red: Double((rgb >> 16) & 0xFF) / 255,
         green: Double((rgb >> 8) & 0xFF) / 255,
         blue: Double(rgb & 0xFF) / 255
      )
   }
}

#Preview("Face") {
   ZStack {
      RideDashboardTheme.void
      RideWordmark(pointSize: 64)
   }
   .ignoresSafeArea()
}

#Preview("Splash") {
   ZStack {
      RideDashboardTheme.void
      RideWordmark(pointSize: 72, chrome: .splash)
   }
   .ignoresSafeArea()
}
