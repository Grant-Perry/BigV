//
//  RouteGuidanceSpeechAnnouncer.swift
//  BigV
//

import AVFAudio
import Foundation

/// Speaks guidance out loud without taking the rider's music away.
///
/// The audio session is the whole difficulty. A navigation app that holds an
/// active `.playback` session for a three-hour ride ducks the rider's music for
/// three hours; one that takes the session exclusively stops it outright. So the
/// session is claimed immediately before an utterance, ducking whatever is
/// playing, and released the moment the synthesizer falls idle — which is why a
/// delegate is worth the ceremony here rather than a poll. The claim itself goes
/// through `RideAudioSession`, which counts claimants, so falling idle here can
/// never clip a radar tone still sounding.
@MainActor
final class RouteGuidanceSpeechAnnouncer {

   // MARK: - Settings

   /// Silences everything without tearing the object down, so the rider's voice
   /// toggle is instant and reversible.
   var isEnabled = true {
      didSet {
         guard !isEnabled else { return }
         silence()
      }
   }

   // MARK: - Private State

   private let synthesizer = AVSpeechSynthesizer()
   private var completionObserver: RouteGuidanceSpeechObserver?
   private var isSessionActive = false

   private var utteranceTask: Task<Void, Never>?

   /// Identifies the newest requested phrase, so only it may clear the pending
   /// flag. Without that, a superseded request would let the session be handed
   /// back from under the phrase about to be spoken.
   private var utteranceToken = 0
   private var isUtterancePending = false

   /// The claim in flight, so two cues arriving together share one activation
   /// rather than racing to speak before the route is up.
   private var claimTask: Task<Bool, Never>?

   // MARK: - Initialization

   init() {
      let observer = RouteGuidanceSpeechObserver { [weak self] in
         self?.releaseSessionWhenIdle()
      }

      // `delegate` is weak, so the observer has to be held here or it dies before
      // the first utterance finishes.
      completionObserver = observer
      synthesizer.delegate = observer
   }

   // MARK: - Speaking

   /// Says one phrase, abandoning anything still being said.
   ///
   /// Guidance never queues: if a second cue arrives while the first is still
   /// playing, the rider is closer to the turn than they were, so the newer
   /// phrase is the only one that still helps.
   func speak(_ phrase: String) {
      let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
      guard isEnabled, !trimmed.isEmpty else { return }

      utteranceTask?.cancel()
      utteranceToken += 1
      isUtterancePending = true

      let token = utteranceToken

      utteranceTask = Task { [weak self] in
         let claimed = await self?.claimSession() == true

         guard let self, token == utteranceToken else { return }
         isUtterancePending = false

         guard claimed, !Task.isCancelled, isEnabled else { return }
         utter(trimmed)
      }
   }

   /// Stops mid-phrase and hands the audio session back.
   func silence() {
      utteranceTask?.cancel()
      utteranceTask = nil
      utteranceToken += 1
      isUtterancePending = false

      if synthesizer.isSpeaking {
         synthesizer.stopSpeaking(at: .immediate)
      }

      releaseSession()
   }

   private func utter(_ phrase: String) {
      if synthesizer.isSpeaking {
         synthesizer.stopSpeaking(at: .immediate)
      }

      let utterance = AVSpeechUtterance(string: phrase)
      utterance.rate = AVSpeechUtteranceDefaultSpeechRate
      utterance.volume = 1

      synthesizer.speak(utterance)

      DebugPrint(mode: .navigation, "Announced: \(phrase)")
   }

   // MARK: - Audio Session

   private func claimSession() async -> Bool {
      if isSessionActive { return true }
      if let claimTask { return await claimTask.value }

      let task = Task<Bool, Never> {
         guard let failure = await RideAudioSession.shared.claim(.guidanceSpeech) else {
            return true
         }
         DebugPrint(mode: .navigation, "Could not claim the audio session: \(failure)")
         return false
      }
      claimTask = task

      let claimed = await task.value
      claimTask = nil
      isSessionActive = claimed

      return claimed
   }

   private func releaseSessionWhenIdle() {
      guard !synthesizer.isSpeaking, !isUtterancePending else { return }
      releaseSession()
   }

   private func releaseSession() {
      guard isSessionActive else { return }
      isSessionActive = false

      Task {
         guard let failure = await RideAudioSession.shared.release(.guidanceSpeech) else { return }
         DebugPrint(mode: .navigation, "Could not release the audio session: \(failure)")
      }
   }
}

// MARK: - Completion Observer

/// Bridges `AVSpeechSynthesizer`'s Objective-C delegate back onto the main actor.
///
/// `nonisolated` because the protocol it conforms to carries no isolation of its
/// own; the only stored value is a `Sendable` closure, so the type is safe to
/// exist outside any actor.
private nonisolated final class RouteGuidanceSpeechObserver: NSObject, AVSpeechSynthesizerDelegate {

   private let onIdle: @MainActor @Sendable () -> Void

   init(onIdle: @escaping @MainActor @Sendable () -> Void) {
      self.onIdle = onIdle
      super.init()
   }

   func speechSynthesizer(
      _ synthesizer: AVSpeechSynthesizer,
      didFinish utterance: AVSpeechUtterance
   ) {
      notifyIdle()
   }

   func speechSynthesizer(
      _ synthesizer: AVSpeechSynthesizer,
      didCancel utterance: AVSpeechUtterance
   ) {
      notifyIdle()
   }

   private func notifyIdle() {
      let onIdle = self.onIdle
      Task { @MainActor in onIdle() }
   }
}
