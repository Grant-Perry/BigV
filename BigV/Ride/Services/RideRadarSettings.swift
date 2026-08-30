//
//  RideRadarSettings.swift
//  BigV
//

import Foundation

// MARK: - Placement

/// Which screen edge the radar tape rides.
///
/// The tape is an overlay on every edge — it never reserves a gutter, because
/// giving up cockpit width for a rail the rider only glances at is the wrong
/// trade. Left and right run the Garmin vertical convention; top and bottom run
/// the same scale horizontally with the rider at the right-hand end.
enum RideRadarPlacement: String, CaseIterable, Sendable, Identifiable {

   case leading
   case trailing
   case top
   case bottom

   var id: String { rawValue }

   var title: String {
      switch self {
         case .leading: "Left"
         case .trailing: "Right"
         case .top: "Top"
         case .bottom: "Bottom"
      }
   }

   /// Vertical tapes read rider-at-top; horizontal tapes read rider-at-right.
   var isVertical: Bool {
      self == .leading || self == .trailing
   }
}

// MARK: - Tone Style

/// How the audio announcer voices a threat, matching Garmin's own choices.
enum RideRadarToneStyle: String, CaseIterable, Sendable, Identifiable {

   /// One tone on threat entry, silence after.
   case single

   /// A tone per tier change, so escalation is audible.
   case multi

   var id: String { rawValue }

   var title: String {
      switch self {
         case .single: "Single tone"
         case .multi: "Multi tone"
      }
   }
}

// MARK: - Settings

/// Every rider-facing radar preference, observable and persisted.
///
/// UserDefaults cannot notify `@Observable` tracking, so each preference is a
/// stored mirror loaded once and written through on set — the same string keys
/// the `guidance.voice.enabled` pattern uses, one surface writing them.
@Observable
@MainActor
final class RideRadarSettings {

   // MARK: - Keys

   private enum Key {
      static let enabled = "radar.enabled"
      static let side = "radar.side"
      static let alertHaptics = "radar.alert.haptics"
      static let alertAudio = "radar.alert.audio"
      static let alertTone = "radar.alert.tone"
      static let alertClearTone = "radar.alert.clearTone"
      static let overlayEnabled = "radar.overlay.enabled"
      static let disclaimerAcknowledged = "radar.disclaimer.acknowledged"
      static let simulatorEnabled = "radar.simulator"
   }

   @ObservationIgnored private let defaults: UserDefaults

   // MARK: - Preferences

   /// The master switch: whether BigVelo opens the radar link at all.
   var isEnabled: Bool {
      didSet { defaults.set(isEnabled, forKey: Key.enabled) }
   }

   var placement: RideRadarPlacement {
      didSet { defaults.set(placement.rawValue, forKey: Key.side) }
   }

   var alertHapticsEnabled: Bool {
      didSet { defaults.set(alertHapticsEnabled, forKey: Key.alertHaptics) }
   }

   var alertAudioEnabled: Bool {
      didSet { defaults.set(alertAudioEnabled, forKey: Key.alertAudio) }
   }

   var toneStyle: RideRadarToneStyle {
      didSet { defaults.set(toneStyle.rawValue, forKey: Key.alertTone) }
   }

   /// Garmin offers the all-clear chime separately from threat tones.
   var clearToneEnabled: Bool {
      didSet { defaults.set(clearToneEnabled, forKey: Key.alertClearTone) }
   }

   /// The screen-edge tint on tier entry.
   var overlayEnabled: Bool {
      didSet { defaults.set(overlayEnabled, forKey: Key.overlayEnabled) }
   }

   /// Set once the rider has seen the first-connect safety disclaimer.
   var hasAcknowledgedDisclaimer: Bool {
      didSet { defaults.set(hasAcknowledgedDisclaimer, forKey: Key.disclaimerAcknowledged) }
   }

   #if DEBUG
   /// Scripted traffic instead of a radio — the App Review demo path.
   var simulatorEnabled: Bool {
      didSet { defaults.set(simulatorEnabled, forKey: Key.simulatorEnabled) }
   }
   #endif

   // MARK: - Initialization

   init(defaults: UserDefaults = .standard) {
      self.defaults = defaults

      isEnabled = defaults.bool(forKey: Key.enabled)
      placement = RideRadarPlacement(rawValue: defaults.string(forKey: Key.side) ?? "") ?? .trailing
      alertHapticsEnabled = defaults.object(forKey: Key.alertHaptics) as? Bool ?? true
      alertAudioEnabled = defaults.object(forKey: Key.alertAudio) as? Bool ?? true
      toneStyle = RideRadarToneStyle(rawValue: defaults.string(forKey: Key.alertTone) ?? "") ?? .multi
      clearToneEnabled = defaults.object(forKey: Key.alertClearTone) as? Bool ?? true
      overlayEnabled = defaults.object(forKey: Key.overlayEnabled) as? Bool ?? true
      hasAcknowledgedDisclaimer = defaults.bool(forKey: Key.disclaimerAcknowledged)

      #if DEBUG
      simulatorEnabled = defaults.bool(forKey: Key.simulatorEnabled)
      #endif
   }
}
