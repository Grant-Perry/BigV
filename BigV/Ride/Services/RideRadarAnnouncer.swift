//
//  RideRadarAnnouncer.swift
//  BigV
//

import AVFAudio
import Foundation

/// Audio tones for radar alerts: approach, danger, and the all-clear.
///
/// The tones are synthesized, not bundled — three short sine patterns rendered
/// once into PCM buffers and played through a tiny `AVAudioEngine`. That keeps
/// the app free of audio assets and makes the tones exactly as long as they
/// need to be: a radar alert that talks over itself is worse than none.
///
/// The audio session is shared plumbing. `RideAudioSession` counts claimants,
/// so a tone can sound while turn-by-turn speech holds the session and neither
/// side can deactivate it out from under the other. Tones duck the rider's
/// music (`.duckOthers` rides the shared configuration) and the claim is
/// handed back a beat after the last tone, so a burst of alerts does not
/// bounce the music volume on every beep.
///
/// Driven from `RideSessionManager.process(_:)` off the same tracker edges
/// that bump `alertPulse` / `clearPulse` — never per frame.
@MainActor
final class RideRadarAnnouncer {

   // MARK: - Dependencies

   private let rideRadarSettings: RideRadarSettings

   // MARK: - Playback State

   private var engine: AVAudioEngine?
   private var playerNode: AVAudioPlayerNode?
   private var toneBuffers: [Tone: AVAudioPCMBuffer] = [:]

   /// Identifies the newest requested tone, so a superseded completion cannot
   /// tear the engine down under the tone that replaced it.
   private var toneToken = 0

   private var isSessionActive = false
   private var claimTask: Task<Bool, Never>?
   private var idleTask: Task<Void, Never>?

   /// How long the engine and session linger after a tone, so an approach
   /// beep followed by an escalation seconds later does not bounce the
   /// rider's music volume twice.
   private let idleLinger: TimeInterval = 2

   // MARK: - Initialization

   init(rideRadarSettings: RideRadarSettings) {
      self.rideRadarSettings = rideRadarSettings
   }

   // MARK: - Announcing

   /// A vehicle entered the board. The one tone every style plays.
   func announceApproach() {
      guard rideRadarSettings.alertAudioEnabled else { return }
      play(.approach)
   }

   /// A tracked vehicle escalated to the high tier. Only the multi-tone style
   /// voices escalation; single-tone riders asked for threat entry and silence.
   func announceDanger() {
      guard rideRadarSettings.alertAudioEnabled,
            rideRadarSettings.toneStyle == .multi
      else { return }
      play(.danger)
   }

   /// The board emptied. Separately gated, matching Garmin's own toggle.
   func announceAllClear() {
      guard rideRadarSettings.alertAudioEnabled,
            rideRadarSettings.clearToneEnabled
      else { return }
      play(.allClear)
   }

   // MARK: - Playback

   private func play(_ tone: Tone) {
      idleTask?.cancel()
      idleTask = nil

      toneToken += 1
      let token = toneToken

      Task { [weak self] in
         guard let self else { return }

         let claimed = await self.claimSession()
         guard claimed, token == self.toneToken else { return }
         self.schedule(tone, token: token)
      }
   }

   private func schedule(_ tone: Tone, token: Int) {
      guard let playerNode = preparePlayback(),
            let buffer = buffer(for: tone)
      else {
         settleWhenIdle(after: token)
         return
      }

      // Stopping fires the previous buffer's completion; the token mismatch
      // makes that a no-op.
      playerNode.stop()

      playerNode.scheduleBuffer(
         buffer,
         completionCallbackType: .dataPlayedBack
      ) { [weak self] _ in
         Task { @MainActor in
            self?.settleWhenIdle(after: token)
         }
      }
      playerNode.play()

      DebugPrint(mode: .radar, "Radar tone: \(tone)")
   }

   /// After the tone finishes, linger briefly, then park the engine and hand
   /// the audio session back — unless a newer tone claimed it meanwhile.
   private func settleWhenIdle(after token: Int) {
      guard token == toneToken else { return }

      idleTask?.cancel()
      idleTask = Task { [weak self] in
         try? await Task.sleep(for: .seconds(self?.idleLinger ?? 0))
         guard !Task.isCancelled else { return }
         self?.parkPlayback()
      }
   }

   private func parkPlayback() {
      playerNode?.stop()
      engine?.stop()
      releaseSession()
   }

   // MARK: - Engine

   private func preparePlayback() -> AVAudioPlayerNode? {
      if engine == nil {
         let engine = AVAudioEngine()
         let node = AVAudioPlayerNode()

         engine.attach(node)
         engine.connect(node, to: engine.mainMixerNode, format: Self.format)

         self.engine = engine
         playerNode = node
      }

      guard let engine, let playerNode else { return nil }

      if !engine.isRunning {
         do {
            try engine.start()
         } catch {
            DebugPrint(
               mode: .radar,
               "Radar tone engine failed to start: \(error.localizedDescription)"
            )
            return nil
         }
      }

      return playerNode
   }

   private func buffer(for tone: Tone) -> AVAudioPCMBuffer? {
      if let cached = toneBuffers[tone] { return cached }

      guard let rendered = Self.render(tone) else {
         DebugPrint(mode: .radar, "Could not render radar tone \(tone)")
         return nil
      }

      toneBuffers[tone] = rendered
      return rendered
   }

   // MARK: - Audio Session

   private func claimSession() async -> Bool {
      if isSessionActive { return true }
      if let claimTask { return await claimTask.value }

      let task = Task<Bool, Never> {
         guard let failure = await RideAudioSession.shared.claim(.radarTones) else {
            return true
         }
         DebugPrint(mode: .radar, "Could not claim the audio session: \(failure)")
         return false
      }
      claimTask = task

      let claimed = await task.value
      claimTask = nil
      isSessionActive = claimed

      return claimed
   }

   private func releaseSession() {
      guard isSessionActive else { return }
      isSessionActive = false

      Task {
         guard let failure = await RideAudioSession.shared.release(.radarTones) else { return }
         DebugPrint(mode: .radar, "Could not release the audio session: \(failure)")
      }
   }
}

// MARK: - Tones

extension RideRadarAnnouncer {

   /// The three patterns, tuned to be told apart without looking: approach
   /// rises, danger stabs three times high, all-clear falls away.
   enum Tone: Hashable, CustomStringConvertible {

      case approach
      case danger
      case allClear

      /// The pattern as (frequency Hz, duration s) beeps with one gap length.
      var beeps: [(frequency: Double, duration: Double)] {
         switch self {
            case .approach: [(660, 0.09), (880, 0.11)]
            case .danger: [(1245, 0.07), (1245, 0.07), (1245, 0.09)]
            case .allClear: [(880, 0.09), (587, 0.14)]
         }
      }

      var gap: Double {
         switch self {
            case .approach: 0.05
            case .danger: 0.045
            case .allClear: 0.06
         }
      }

      var amplitude: Double {
         switch self {
            case .approach: 0.7
            case .danger: 0.85
            case .allClear: 0.5
         }
      }

      var description: String {
         switch self {
            case .approach: "approach"
            case .danger: "danger"
            case .allClear: "all clear"
         }
      }
   }

   private static let sampleRate: Double = 44_100

   static var format: AVAudioFormat? {
      AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
   }

   /// Renders one tone into a PCM buffer: sine beeps with a short linear
   /// attack and release so they land as chimes, not clicks.
   private static func render(_ tone: Tone) -> AVAudioPCMBuffer? {
      guard let format else { return nil }

      let gapFrames = Int(tone.gap * sampleRate)
      let beepFrames = tone.beeps.map { Int($0.duration * sampleRate) }
      let totalFrames = beepFrames.reduce(0, +)
         + gapFrames * max(0, tone.beeps.count - 1)
         + gapFrames // trailing silence so the release never truncates

      guard totalFrames > 0,
            let buffer = AVAudioPCMBuffer(
               pcmFormat: format,
               frameCapacity: AVAudioFrameCount(totalFrames)
            ),
            let samples = buffer.floatChannelData?[0]
      else { return nil }

      buffer.frameLength = AVAudioFrameCount(totalFrames)

      let rampFrames = Int(0.008 * sampleRate)
      var cursor = 0

      for (index, beep) in tone.beeps.enumerated() {
         let frames = beepFrames[index]

         for frame in 0..<frames {
            let envelope: Double = if frame < rampFrames {
               Double(frame) / Double(rampFrames)
            } else if frame >= frames - rampFrames {
               Double(frames - frame) / Double(rampFrames)
            } else {
               1
            }

            let phase = 2 * Double.pi * beep.frequency * Double(frame) / sampleRate
            samples[cursor + frame] = Float(sin(phase) * envelope * tone.amplitude)
         }

         cursor += frames

         if index < tone.beeps.count - 1 {
            for frame in 0..<gapFrames {
               samples[cursor + frame] = 0
            }
            cursor += gapFrames
         }
      }

      for frame in cursor..<totalFrames {
         samples[frame] = 0
      }

      return buffer
   }
}
