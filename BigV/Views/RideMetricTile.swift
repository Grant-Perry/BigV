//
//  RideMetricTile.swift
//  BigV
//

import SwiftUI

/// One metric on the ride dashboard.
///
/// Left-column tiles trail into the gutter. Right-column tiles lead from it.
/// Chartable tiles can pin their series to the hero when tapped.
struct RideMetricTile: View {

   let title: String
   let value: String
   var unit: String?
   var identifier: String?
   var gutterAlignment: HorizontalAlignment = .leading
   var action: (() -> Void)?
   var isSelected: Bool = false

   /// Landscape packs three tiles across a short column, so the numeral and the
   /// padding both come down and the gutter alternation stops meaning anything.
   var isCompact: Bool = false

   /// Holding the card opens the picker that decides what it shows. Alongside
   /// the tap rather than instead of it, so a chartable card still charts.
   var onLongPress: (() -> Void)?

   var body: some View {
      Group {
         if let action {
            Button(action: action) {
               tileContent
            }
            .buttonStyle(.plain)
         } else {
            tileContent
         }
      }
      .rideCardLongPress(onLongPress)
      .overlay {
         if isSelected {
            RoundedRectangle(cornerRadius: RideDashboardTheme.cardRadius, style: .continuous)
               .strokeBorder(RideDashboardTheme.ice.opacity(0.85), lineWidth: 2)
         }
      }
   }

   private var tileContent: some View {
      VStack(alignment: isCompact ? .leading : gutterAlignment, spacing: 2) {
         Text(title)
            .font(.caption2.weight(.semibold))
            .kerning(isCompact ? 0.5 : 1)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(RideDashboardTheme.ink(isSelected ? 0.75 : 0.55))
            .frame(maxWidth: .infinity, alignment: frameAlignment)

         HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
               .font(.system(size: isCompact ? 26 : 34, weight: .semibold, design: .rounded))
               .monospacedDigit()
               .foregroundStyle(RideDashboardTheme.ink)
               .lineLimit(1)
               .minimumScaleFactor(0.6)
               .accessibilityIdentifier(identifier ?? title)
               .accessibilityLabel(title)
               .accessibilityValue(unit.map { "\(value) \($0)" } ?? value)
               .accessibilityAddTraits(isSelected ? [.isSelected] : [])

            if let unit {
               Text(unit)
                  .font(.caption.weight(.semibold))
                  .lineLimit(1)
                  .fixedSize()
                  .foregroundStyle(RideDashboardTheme.ink(0.45))
            }
         }
         .frame(maxWidth: .infinity, alignment: frameAlignment)
      }
      .frame(maxWidth: .infinity, alignment: frameAlignment)
      .padding(.horizontal, isCompact ? 10 : 14)
      .padding(.vertical, isCompact ? 8 : 12)
      .rideGlassCard(density: .hud)
   }

   private var frameAlignment: Alignment {
      guard !isCompact else { return .leading }
      return gutterAlignment == .trailing ? .trailing : .leading
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      HStack(spacing: 10) {
         RideMetricTile(
            title: "DISTANCE",
            value: "12.84",
            unit: "MI",
            gutterAlignment: .trailing,
            isSelected: true
         )
         RideMetricTile(title: "RIDE TIME", value: "1:12:04", gutterAlignment: .leading)
      }
      .padding()
   }
}

// MARK: - Long Press

/// The hold that opens the card picker, as a UIKit recognizer.
///
/// UIKit rather than SwiftUI's `LongPressGesture` because the dashboard's
/// cards live inside a scroll view, and a `UILongPressGestureRecognizer`
/// negotiates with a scroll view the way every UIKit long press does: a
/// still finger fires it, a moving one scrolls, and neither is lost to the
/// other. Recognising cancels the touch for the card beneath, so a chartable
/// card held down does not also toggle its chart on release.
private struct RideCardLongPressRecognizer: UIGestureRecognizerRepresentable {

   let onPress: () -> Void

   func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
      let recognizer = UILongPressGestureRecognizer()
      recognizer.minimumPressDuration = 0.45
      recognizer.allowableMovement = 12
      return recognizer
   }

   func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
      guard recognizer.state == .began else { return }
      onPress()
   }
}

extension View {

   /// The hold that opens the card picker. Alongside whatever the card
   /// already does on a tap, and absent entirely when the host passes
   /// nothing, so cards outside the cockpit keep behaving as plain glass.
   @ViewBuilder
   func rideCardLongPress(_ onLongPress: (() -> Void)?) -> some View {
      if let onLongPress {
         gesture(RideCardLongPressRecognizer(onPress: onLongPress))
      } else {
         self
      }
   }
}
