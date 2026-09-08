//
//  RideCockpitMetricPickerView.swift
//  BigV
//

import SwiftUI

/// The full-width glass picker a held card drops down.
///
/// Rows are the size of the cards they stand in for, not menu items: a gloved
/// thumb on a moving bike gets a target the height of a tile, the whole width
/// of the screen, showing the metric's live number so the rider is choosing a
/// figure they can see rather than a name they have to imagine.
///
/// Two groups. SWAP WITH is every card already on this screen: pick one and
/// the two trade places. REPLACE WITH is every metric that is not: pick one
/// and it takes the held card's slot. A protected card shows the first group
/// only — distance and ride time can move, never leave.
struct RideCockpitMetricPickerView: View {

   let request: RideCockpitMetricSwapRequest
   let choices: RideCockpitMetricChoices
   let readouts: RideCockpitMetricReadouts
   let onSelect: (RideCockpitMetric) -> Void
   let onCancel: () -> Void

   var body: some View {
      ZStack(alignment: .top) {
         // The backdrop is the way out: anywhere that is not a row cancels.
         RideDashboardTheme.void.opacity(0.55)
            .ignoresSafeArea()
            .contentShape(.rect)
            .onTapGesture(perform: onCancel)
            .accessibilityLabel("Cancel")
            .accessibilityAddTraits(.isButton)

         panel
            .padding(.horizontal, 12)
            .padding(.top, 8)
      }
      .accessibilityIdentifier("ride.picker.metric")
   }

   // MARK: - Panel

   private var panel: some View {
      VStack(spacing: 0) {
         header
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

         ScrollView(.vertical) {
            VStack(spacing: 8) {
               if choices.isEmpty {
                  emptyNote
               }

               if !choices.swaps.isEmpty {
                  section("SWAP WITH", metrics: choices.swaps)
               }

               if !choices.replacements.isEmpty {
                  section("REPLACE WITH", metrics: choices.replacements)
               }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
         }
         .scrollIndicators(.hidden)
         .scrollBounceBehavior(.basedOnSize)
      }
      .frame(maxWidth: .infinity)
      .frame(maxHeight: 560)
      .fixedSize(horizontal: false, vertical: true)
      .rideGlassCard(density: .hud, cornerRadius: RideDashboardTheme.chromeRadius)
   }

   private var header: some View {
      HStack(spacing: 10) {
         Image(systemName: request.metric.symbolName)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(RideDashboardTheme.ice)
            .frame(width: 22)

         VStack(alignment: .leading, spacing: 2) {
            Text(request.metric.title)
               .font(.caption.weight(.bold))
               .kerning(1.2)
               .foregroundStyle(RideDashboardTheme.ink)

            Text(headerHint)
               .font(.caption2)
               .foregroundStyle(RideDashboardTheme.ink(0.55))
         }

         Spacer(minLength: 8)

         Button(action: onCancel) {
            Image(systemName: "xmark")
               .font(.caption.weight(.bold))
               .foregroundStyle(RideDashboardTheme.ink(0.75))
               .frame(width: 36, height: 36)
               .contentShape(.circle)
         }
         .buttonStyle(.plain)
         .rideGlassChrome(in: Circle())
         .accessibilityLabel("Cancel")
      }
   }

   private var headerHint: String {
      request.metric.isProtected
         ? "Always on this screen. Pick a card to trade places with."
         : "Pick what this card shows."
   }

   private var emptyNote: some View {
      Text("Nothing else to show here yet.")
         .font(.footnote)
         .foregroundStyle(RideDashboardTheme.ink(0.5))
         .frame(maxWidth: .infinity)
         .padding(.vertical, 18)
   }

   // MARK: - Sections

   private func section(_ title: String, metrics: [RideCockpitMetric]) -> some View {
      VStack(alignment: .leading, spacing: 6) {
         Text(title)
            .font(.caption2.weight(.bold))
            .kerning(1)
            .foregroundStyle(RideDashboardTheme.ink(0.5))
            .padding(.horizontal, 6)
            .padding(.top, 6)

         ForEach(metrics) { metric in
            row(metric)
         }
      }
   }

   private func row(_ metric: RideCockpitMetric) -> some View {
      let readout = readouts.readout(for: metric)

      return Button {
         onSelect(metric)
      } label: {
         HStack(spacing: 12) {
            Image(systemName: metric.symbolName)
               .font(.headline.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ice)
               .frame(width: 26)

            Text(metric.menuTitle)
               .font(.subheadline.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ink)
               .lineLimit(1)

            Spacer(minLength: 8)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
               Text(readout?.value ?? RideFormatters.placeholder)
                  .font(.system(size: 22, weight: .semibold, design: .rounded))
                  .monospacedDigit()
                  .foregroundStyle(RideDashboardTheme.ink(0.92))
                  .lineLimit(1)
                  .minimumScaleFactor(0.7)

               if let unit = readout?.unit {
                  Text(unit)
                     .font(.caption2.weight(.semibold))
                     .foregroundStyle(RideDashboardTheme.ink(0.45))
               }
            }
         }
         .frame(maxWidth: .infinity)
         .frame(minHeight: 56)
         .padding(.horizontal, 14)
         .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .rideGlassCard(density: .hud)
      .accessibilityLabel(metric.menuTitle)
      .accessibilityValue(readout.map { "\($0.value) \($0.unit ?? "")" } ?? "")
      .accessibilityIdentifier("ride.picker." + metric.rawValue)
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      RideCockpitMetricPickerView(
         request: RideCockpitMetricSwapRequest(metric: .altitude, surface: .dashboard),
         choices: RideCockpitMetricChoices(
            swaps: [.distance, .rideTime, .elevationGain, .grade],
            replacements: [.averageSpeed, .maximumSpeed]
         ),
         readouts: RideCockpitMetricReadouts(
            rideViewModel: RideViewModel(),
            rideClimbModel: RideClimbModel(),
            routeGuidanceViewModel: RouteGuidanceViewModel()
         ),
         onSelect: { _ in },
         onCancel: {}
      )
   }
   .preferredColorScheme(.dark)
}
