//
//  RideSettingsSegmentedControl.swift
//  BigV
//

import SwiftUI

/// One option inside a settings segmented control.
///
/// `title` is what the rider reads and `accessibilityLabel` is what VoiceOver
/// says, because the two diverge the moment a segment gets short enough to fit
/// — "°F" on screen has to speak as "Fahrenheit".
struct RideSettingsSegment<Value: Hashable>: Identifiable {

   let value: Value
   let title: String
   var symbolName: String?
   var accessibilityLabel: String?
   var identifier: String = ""

   var id: Value { value }
}

/// A cockpit segmented control: graphite track, ice thumb that slides between
/// options under a snappy spring.
///
/// This replaces the stack of full-width check-circle rows setup used to carry.
/// Two to five short options that fit on one line are a segment, not a list —
/// the whole choice stays visible, comparison is side by side, and the card
/// costs one row instead of one row per option.
struct RideSettingsSegmentedControl<Value: Hashable>: View {

   /// `hug` sizes the control to its widest option and no further, for a
   /// control that shares a row with a label. `fill` spreads across the row.
   enum Width: Sendable {
      case hug
      case fill
   }

   @Binding var selection: Value
   let segments: [RideSettingsSegment<Value>]
   var width: Width = .fill
   var accent: Color = RideDashboardTheme.ice

   @Namespace private var thumbNamespace

   var body: some View {
      HStack(spacing: 2) {
         ForEach(segments) { segment in
            segmentButton(for: segment)
         }
      }
      .padding(3)
      .background(RideDashboardTheme.ink(0.06), in: .capsule)
      .overlay {
         Capsule(style: .continuous)
            .strokeBorder(RideDashboardTheme.ink(0.09), lineWidth: 1)
      }
      .animation(.snappy(duration: 0.26, extraBounce: 0.06), value: selection)
      .sensoryFeedback(.selection, trigger: selection)
   }

   // MARK: - Segments

   @ViewBuilder
   private func segmentButton(for segment: RideSettingsSegment<Value>) -> some View {
      let isSelected = segment.value == selection

      let button = Button {
         guard !isSelected else { return }
         selection = segment.value
      } label: {
         label(for: segment, isSelected: isSelected)
            .padding(.vertical, 8)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: width == .fill ? .infinity : nil)
            .background {
               if isSelected {
                  Capsule(style: .continuous)
                     .fill(accent)
                     .shadow(color: accent.opacity(0.35), radius: 5, y: 1)
                     .matchedGeometryEffect(id: Self.thumbID, in: thumbNamespace)
               }
            }
            .contentShape(.capsule)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(segment.accessibilityLabel ?? segment.title)
      .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)

      if segment.identifier.isEmpty {
         button
      } else {
         button.accessibilityIdentifier(segment.identifier)
      }
   }

   /// Every option is drawn hidden behind the real one, so a segment is as wide
   /// as the longest label in the set. Without it the thumb would resize as it
   /// travelled and the track would breathe on every tap.
   private func label(for segment: RideSettingsSegment<Value>, isSelected: Bool) -> some View {
      ZStack {
         ForEach(segments) { ghost in
            content(for: ghost)
               .hidden()
         }

         content(for: segment)
            .foregroundStyle(isSelected ? RideDashboardTheme.onAccent : RideDashboardTheme.ink(0.55))
      }
   }

   /// Weight never changes with selection — colour carries it. A bold selected
   /// label would be wider than the hidden sizing pass and jitter the row.
   private func content(for segment: RideSettingsSegment<Value>) -> some View {
      HStack(spacing: 4) {
         if let symbolName = segment.symbolName {
            Image(systemName: symbolName)
               .font(.caption2.weight(.semibold))
         }

         Text(segment.title)
            .font(.caption.weight(.semibold))
      }
      .lineLimit(1)
      .minimumScaleFactor(0.8)
   }

   // MARK: - Metrics

   private static var thumbID: String { "settings.segment.thumb" }

   /// Five segments on a 320-point phone cannot afford twelve points a side.
   private var horizontalPadding: CGFloat {
      segments.count > 3 ? 9 : 13
   }
}

// MARK: - Labelled Row

/// A settings row that reads label-left, choice-right — and stacks the choice
/// under the label once text size no longer allows that.
///
/// `ViewThatFits` does the deciding, so an accessibility text size gets a
/// full-width control instead of a truncated one, with no size class guessing.
struct RideSettingsSegmentedRow<Value: Hashable>: View {

   let title: String
   @Binding var selection: Value
   let segments: [RideSettingsSegment<Value>]
   var accent: Color = RideDashboardTheme.ice

   var body: some View {
      ViewThatFits(in: .horizontal) {
         HStack(spacing: 12) {
            titleLabel

            Spacer(minLength: 12)

            control(width: .hug)
         }

         VStack(alignment: .leading, spacing: 8) {
            titleLabel

            control(width: .fill)
         }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
   }

   private var titleLabel: some View {
      Text(title)
         .font(.subheadline.weight(.semibold))
         .foregroundStyle(RideDashboardTheme.ink)
         .fixedSize(horizontal: false, vertical: true)
   }

   private func control(width: RideSettingsSegmentedControl<Value>.Width) -> some View {
      RideSettingsSegmentedControl(
         selection: $selection,
         segments: segments,
         width: width,
         accent: accent
      )
   }
}

#Preview {
   @Previewable @State var system: RideUnitSystem = .imperial
   @Previewable @State var mode: RideAppearanceMode = .dark
   @Previewable @State var lap: Double = 5

   ZStack {
      RideAtmosphereBackground()

      VStack(spacing: 14) {
         RideSettingsSegmentedRow(
            title: "Measurement",
            selection: $system,
            segments: RideUnitSystem.allCases.map {
               RideSettingsSegment(value: $0, title: $0.title)
            }
         )

         RideSettingsSegmentedRow(
            title: "Auto-Lap",
            selection: $lap,
            segments: [0, 1, 5, 10, 25].map {
               RideSettingsSegment(value: $0, title: $0 == 0 ? "Off" : "\(Int($0))")
            }
         )

         RideSettingsSegmentedControl(
            selection: $mode,
            segments: RideAppearanceMode.allCases.map {
               RideSettingsSegment(value: $0, title: $0.title, symbolName: $0.symbolName)
            }
         )
      }
      .padding(14)
      .rideGlassCard()
      .padding(16)
   }
   .preferredColorScheme(.dark)
}
