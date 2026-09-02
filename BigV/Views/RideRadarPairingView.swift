//
//  RideRadarPairingView.swift
//  BigV
//

import SwiftUI

/// The radar's home: pairing, connection health, and every alert preference.
///
/// A self-contained sheet reached from the radar chip — the app's first
/// settings surface, kept deliberately small.
struct RideRadarPairingView: View {

   @Bindable var pairingViewModel: RideRadarPairingViewModel

   @Environment(\.dismiss) private var dismiss

   var body: some View {
      NavigationStack {
         ScrollView {
            VStack(spacing: 12) {
               if pairingViewModel.needsDisclaimer {
                  RideRadarDisclaimerCard {
                     pairingViewModel.acknowledgeDisclaimer()
                  }
               }

               enableCard

               if pairingViewModel.isEnabled {
                  connectionCard
                  alertsCard
                  displayCard

                  #if DEBUG
                  simulatorCard
                  #endif
               }

               footnote
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
         }
         .scrollIndicators(.hidden)
         // A background rather than a ZStack sibling: a full-bleed layer inside
         // a stack inflates the stack past the safe area and the scroll view
         // loses its navigation-bar inset, so the title lands on the first card.
         .background {
            RideAtmosphereBackground()
               .ignoresSafeArea()
         }
         .navigationTitle("Rear Radar")
         .navigationBarTitleDisplayMode(.large)
         .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
               Button("Done") { dismiss() }
            }
         }
      }
      .rideAppearance()
      .onDisappear { pairingViewModel.endScan() }
   }

   // MARK: - Enable

   private var enableCard: some View {
      Toggle(isOn: $pairingViewModel.isEnabled) {
         VStack(alignment: .leading, spacing: 2) {
            Text("Rear Radar")
               .font(.subheadline.weight(.semibold))
               .foregroundStyle(RideDashboardTheme.ink)

            Text("Warns you about vehicles approaching from behind")
               .font(.caption)
               .foregroundStyle(RideDashboardTheme.ink(0.55))
         }
      }
      .tint(RideDashboardTheme.go)
      .padding(14)
      .rideGlassCard()
      .accessibilityIdentifier("radar.toggle.enabled")
   }

   // MARK: - Connection

   private var connectionCard: some View {
      VStack(alignment: .leading, spacing: 12) {
         cardHeader("CONNECTION")

         HStack(spacing: 10) {
            statusDot

            VStack(alignment: .leading, spacing: 1) {
               Text(pairingViewModel.connectedName ?? pairingViewModel.connectionText)
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(RideDashboardTheme.ink)

               if pairingViewModel.connectedName != nil {
                  Text(pairingViewModel.connectionText)
                     .font(.caption)
                     .foregroundStyle(RideDashboardTheme.ink(0.55))
               }
            }

            Spacer()

            if pairingViewModel.isConnecting {
               Button("Cancel") { pairingViewModel.cancelConnecting() }
                  .font(.caption.weight(.semibold))
                  .tint(RideDashboardTheme.amber)
            } else if let battery = pairingViewModel.batteryText {
               Label(battery, systemImage: "battery.75percent")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(RideDashboardTheme.ink(0.7))
            }
         }

         if let issue = pairingViewModel.issueMessage {
            Text(issue)
               .font(.caption)
               .foregroundStyle(RideDashboardTheme.amber)
               .fixedSize(horizontal: false, vertical: true)
         }

         if let model = pairingViewModel.modelName {
            detailRow("Model", model)
         }

         if let firmware = pairingViewModel.firmwareVersion {
            detailRow("Firmware", firmware)
         }

         scanSection

         if pairingViewModel.hasRememberedRadar {
            Button(role: .destructive) {
               pairingViewModel.forget()
            } label: {
               Text("Forget Radar")
                  .font(.subheadline.weight(.semibold))
                  .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(RideDashboardTheme.halt)
            .accessibilityIdentifier("radar.button.forget")
         }
      }
      .padding(14)
      .rideGlassCard()
   }

   private var statusDot: some View {
      Circle()
         .fill(pairingViewModel.isConnected ? RideDashboardTheme.go : RideDashboardTheme.amber)
         .frame(width: 9, height: 9)
         .shadow(
            color: (pairingViewModel.isConnected ? RideDashboardTheme.go : RideDashboardTheme.amber).opacity(0.6),
            radius: 4
         )
   }

   // MARK: - Scan

   @ViewBuilder
   private var scanSection: some View {
      if pairingViewModel.isDiscovering {
         VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
               ProgressView()
                  .tint(RideDashboardTheme.ice)

               Text("Searching for radars…")
                  .font(.caption)
                  .foregroundStyle(RideDashboardTheme.ink(0.6))

               Spacer()

               Button("Stop") { pairingViewModel.endScan() }
                  .font(.caption.weight(.semibold))
                  .tint(RideDashboardTheme.ice)
            }

            ForEach(pairingViewModel.discoveries) { discovery in
               Button {
                  pairingViewModel.connect(to: discovery.id)
               } label: {
                  HStack {
                     Image(systemName: "car.rear.waves.up")
                        .font(.caption)
                     Text(discovery.name)
                        .font(.subheadline.weight(.medium))
                     Spacer()
                     Image(systemName: "plus.circle.fill")
                        .foregroundStyle(RideDashboardTheme.ice)
                  }
                  .foregroundStyle(RideDashboardTheme.ink)
                  .padding(.vertical, 8)
                  .padding(.horizontal, 10)
                  .background(RideDashboardTheme.ink(0.06), in: .rect(cornerRadius: 10))
               }
               .buttonStyle(.plain)
            }
         }
      } else if !pairingViewModel.isSimulated {
         Button {
            pairingViewModel.beginScan()
         } label: {
            Label(
               pairingViewModel.hasRememberedRadar ? "Scan for a Different Radar" : "Scan for Radar",
               systemImage: "magnifyingglass"
            )
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
         }
         .buttonStyle(.bordered)
         .tint(RideDashboardTheme.ice)
         .accessibilityIdentifier("radar.button.scan")
      }
   }

   // MARK: - Alerts

   private var alertsCard: some View {
      VStack(alignment: .leading, spacing: 10) {
         cardHeader("ALERTS")

         Toggle("Haptics", isOn: $pairingViewModel.alertHapticsEnabled)
         Toggle("Audio tones", isOn: $pairingViewModel.alertAudioEnabled)

         if pairingViewModel.alertAudioEnabled {
            Picker("Tone style", selection: $pairingViewModel.toneStyle) {
               ForEach(RideRadarToneStyle.allCases) { style in
                  Text(style.title).tag(style)
               }
            }
            .pickerStyle(.segmented)

            Toggle("All-clear tone", isOn: $pairingViewModel.clearToneEnabled)
         }

         Toggle("Screen edge flash", isOn: $pairingViewModel.overlayEnabled)
      }
      .font(.subheadline)
      .foregroundStyle(RideDashboardTheme.ink)
      .tint(RideDashboardTheme.go)
      .padding(14)
      .rideGlassCard()
   }

   // MARK: - Display

   private var displayCard: some View {
      VStack(alignment: .leading, spacing: 10) {
         cardHeader("RADAR TAPE")

         Picker("Placement", selection: $pairingViewModel.placement) {
            ForEach(RideRadarPlacement.allCases) { placement in
               Text(placement.title).tag(placement)
            }
         }
         .pickerStyle(.segmented)
         .accessibilityIdentifier("radar.picker.placement")

         Text(placementHint)
            .font(.caption2)
            .foregroundStyle(RideDashboardTheme.ink(0.45))
      }
      .padding(14)
      .rideGlassCard()
   }

   /// Which way to read the tape, because the two axes put the rider at
   /// different ends and a rider glancing down needs to know which.
   private var placementHint: String {
      pairingViewModel.placement.isVertical
         ? "You sit at the top. Traffic climbs toward you as it closes."
         : "You sit at the right. Traffic runs in from the left as it closes."
   }

   // MARK: - Simulator

   #if DEBUG
   private var simulatorCard: some View {
      VStack(alignment: .leading, spacing: 8) {
         cardHeader("DEVELOPER")

         Toggle(isOn: $pairingViewModel.simulatorEnabled) {
            VStack(alignment: .leading, spacing: 2) {
               Text("Simulated traffic")
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(RideDashboardTheme.ink)

               Text("Scripted vehicles instead of a radio — for demos and review")
                  .font(.caption)
                  .foregroundStyle(RideDashboardTheme.ink(0.55))
            }
         }
         .tint(RideDashboardTheme.ember)
      }
      .padding(14)
      .rideGlassCard()
      .accessibilityIdentifier("radar.toggle.simulator")
   }
   #endif

   // MARK: - Pieces

   private func cardHeader(_ title: String) -> some View {
      Text(title)
         .font(.caption2.weight(.bold))
         .kerning(1.2)
         .foregroundStyle(RideDashboardTheme.ink(0.45))
   }

   private func detailRow(_ label: String, _ value: String) -> some View {
      HStack {
         Text(label)
            .font(.caption)
            .foregroundStyle(RideDashboardTheme.ink(0.55))
         Spacer()
         Text(value)
            .font(.caption.weight(.semibold))
            .foregroundStyle(RideDashboardTheme.ink(0.85))
      }
   }

   private var footnote: some View {
      Text("Works with Garmin Varia™ and compatible Bluetooth cycling radars. BigVelo is not affiliated with Garmin. Radar improves awareness of traffic behind you; it is not a substitute for attentive riding.")
         .font(.caption2)
         .foregroundStyle(RideDashboardTheme.ink(0.35))
         .multilineTextAlignment(.center)
         .padding(.horizontal, 8)
         .padding(.top, 4)
   }
}

// MARK: - Disclaimer

/// Shown once, on the first connect — Garmin's own safety posture, adopted.
private struct RideRadarDisclaimerCard: View {

   let onAcknowledge: () -> Void

   var body: some View {
      VStack(alignment: .leading, spacing: 10) {
         Label("Ride Aware", systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(RideDashboardTheme.amber)

         Text("Radar can improve your awareness of vehicles approaching from behind, but it does not detect everything and cannot prevent a collision. Always ride attentively and follow local road laws.")
            .font(.caption)
            .foregroundStyle(RideDashboardTheme.ink(0.75))

         Button(action: onAcknowledge) {
            Text("I Understand")
               .font(.subheadline.weight(.semibold))
               .frame(maxWidth: .infinity)
         }
         .buttonStyle(.borderedProminent)
         .tint(RideDashboardTheme.amber)
         .accessibilityIdentifier("radar.button.disclaimer")
      }
      .padding(14)
      .rideGlassCard()
   }
}
