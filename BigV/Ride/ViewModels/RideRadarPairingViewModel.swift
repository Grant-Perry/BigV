//
//  RideRadarPairingViewModel.swift
//  BigV
//

import Foundation

/// Presents radar pairing and preferences to the sheet, and nothing else.
///
/// The only place in the app allowed to talk to `RideRadarManager` directly —
/// for discovery, battery and firmware. Ride state still flows exclusively
/// through `RideSessionManager`, which owns the link lifecycle this view model
/// requests.
@Observable
@MainActor
final class RideRadarPairingViewModel {

   // MARK: - Dependencies

   private let rideRadarManager: RideRadarManager
   private let rideSessionManager: RideSessionManager
   private let rideRadarSettings: RideRadarSettings

   init(
      rideRadarManager: RideRadarManager,
      rideSessionManager: RideSessionManager,
      rideRadarSettings: RideRadarSettings
   ) {
      self.rideRadarManager = rideRadarManager
      self.rideSessionManager = rideSessionManager
      self.rideRadarSettings = rideRadarSettings
   }

   // MARK: - Link State

   var connection: RideRadarConnectionState { rideRadarManager.connection }
   var isConnected: Bool { rideRadarManager.connection.isConnected }
   var hasRememberedRadar: Bool { rideRadarManager.hasRememberedRadar }
   var isSimulated: Bool { rideRadarManager.isSimulated }

   var connectedName: String? { rideRadarManager.connectedName }
   var modelName: String? { rideRadarManager.modelName }
   var firmwareVersion: String? { rideRadarManager.firmwareVersion }

   var batteryText: String? {
      rideRadarManager.batteryPercent.map { "\($0)%" }
   }

   var connectionText: String {
      switch rideRadarManager.connection {
         case .disconnected: hasRememberedRadar ? "Disconnected" : "Not paired"
         case .scanning: "Searching…"
         case .connecting: "Connecting…"
         case .connected: "Connected"
      }
   }

   var issueMessage: String? { rideRadarManager.lastIssue?.message }

   var isConnecting: Bool { rideRadarManager.connection == .connecting }

   // MARK: - Discovery

   var discoveries: [RideRadarManager.Discovery] { rideRadarManager.discoveries }
   var isDiscovering: Bool { rideRadarManager.isDiscovering }

   func beginScan() {
      guard rideRadarSettings.isEnabled else { return }
      rideRadarManager.beginDiscovery()
   }

   func endScan() {
      rideRadarManager.endDiscovery()
   }

   func connect(to discoveryID: UUID) {
      rideRadarManager.connect(to: discoveryID)
   }

   func cancelConnecting() {
      rideRadarManager.cancelConnecting()
   }

   func forget() {
      rideRadarManager.forgetPeripheral()
   }

   // MARK: - Enablement

   var isEnabled: Bool {
      get { rideRadarSettings.isEnabled }
      set { setEnabled(newValue) }
   }

   private func setEnabled(_ enabled: Bool) {
      guard rideRadarSettings.isEnabled != enabled else { return }
      rideRadarSettings.isEnabled = enabled

      if enabled {
         rideSessionManager.openRadarLink()
      } else {
         rideSessionManager.closeRadarLink()
      }
   }

   // MARK: - Preferences

   var side: RideRadarSide {
      get { rideRadarSettings.side }
      set { rideRadarSettings.side = newValue }
   }

   var alertHapticsEnabled: Bool {
      get { rideRadarSettings.alertHapticsEnabled }
      set { rideRadarSettings.alertHapticsEnabled = newValue }
   }

   var alertAudioEnabled: Bool {
      get { rideRadarSettings.alertAudioEnabled }
      set { rideRadarSettings.alertAudioEnabled = newValue }
   }

   var toneStyle: RideRadarToneStyle {
      get { rideRadarSettings.toneStyle }
      set { rideRadarSettings.toneStyle = newValue }
   }

   var clearToneEnabled: Bool {
      get { rideRadarSettings.clearToneEnabled }
      set { rideRadarSettings.clearToneEnabled = newValue }
   }

   var overlayEnabled: Bool {
      get { rideRadarSettings.overlayEnabled }
      set { rideRadarSettings.overlayEnabled = newValue }
   }

   // MARK: - Safety Disclaimer

   /// Shown once, on the first connect, matching Garmin's own posture.
   var needsDisclaimer: Bool {
      !rideRadarSettings.hasAcknowledgedDisclaimer && (isConnected || isSimulated)
   }

   func acknowledgeDisclaimer() {
      rideRadarSettings.hasAcknowledgedDisclaimer = true
   }

   // MARK: - Simulator (Debug)

   #if DEBUG
   /// Scripted traffic for App Review and desk work. Restarting the link swaps
   /// the radio for the script (or back) without touching the session's wiring.
   var simulatorEnabled: Bool {
      get { rideRadarSettings.simulatorEnabled }
      set {
         guard rideRadarSettings.simulatorEnabled != newValue else { return }
         rideRadarSettings.simulatorEnabled = newValue

         if rideRadarSettings.isEnabled {
            rideSessionManager.openRadarLink()
         }
      }
   }
   #endif
}
