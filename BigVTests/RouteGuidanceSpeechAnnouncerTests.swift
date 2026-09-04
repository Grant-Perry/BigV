//
//  RouteGuidanceSpeechAnnouncerTests.swift
//  BigVTests
//

import AVFAudio
import Testing
@testable import BigV

@Suite(.serialized)
@MainActor
struct RouteGuidanceSpeechAnnouncerTests {

   @Test func silenceCancelsPendingUtteranceAndReleasesSession() async throws {
      let announcer = RouteGuidanceSpeechAnnouncer()

      // Trigger a speech utterance
      announcer.speak("In 500 feet, turn left on Pine Street")

      // Immediately silence while session claim is in flight or beginning
      announcer.silence()

      // Allow async tasks to settle
      try await Task.sleep(for: .milliseconds(150))

      let hasClaimant = await RideAudioSession.shared.hasClaimant(.guidanceSpeech)
      #expect(!hasClaimant)
   }

   @Test func disabledAnnouncerNeverSpeaksOrClaimsSession() async throws {
      let announcer = RouteGuidanceSpeechAnnouncer()
      announcer.isEnabled = false

      announcer.speak("Turn right")
      try await Task.sleep(for: .milliseconds(50))

      let hasClaimant = await RideAudioSession.shared.hasClaimant(.guidanceSpeech)
      #expect(!hasClaimant)
   }
}
