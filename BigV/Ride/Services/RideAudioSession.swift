//
//  RideAudioSession.swift
//  BigV
//

import AVFAudio
import Foundation

/// The one claim on the system audio session, shared by every sound BigVelo
/// makes mid-ride.
///
/// Two components want the session: turn-by-turn speech and radar alert tones.
/// Each used to activate and deactivate `AVAudioSession` on its own schedule,
/// which is a fight — a guidance phrase ending would hand the session back
/// while a radar tone was still sounding, clipping it. So claims are counted
/// here instead: the session activates on the first claim, stays up while any
/// claimant holds it, and deactivates only when the last one lets go. A radar
/// tone can therefore never be torn down by guidance falling idle, which is
/// what "radar takes priority on threat edges" costs in practice.
///
/// An actor rather than a `@MainActor` type because `setActive` establishes an
/// audio route and can block for tens of milliseconds — a visible hitch on a
/// phone drawing a live map beside active GPS. Errors travel back as text
/// because `Error` is not `Sendable`.
actor RideAudioSession {

   static let shared = RideAudioSession()

   // MARK: - Clients

   /// Everyone allowed to hold the session, as a closed set.
   enum Client: Sendable {
      case guidanceSpeech
      case radarTones
   }

   // MARK: - State

   private var claimants: Set<Client> = []
   private var isActive = false

   // MARK: - Claiming

   /// Activates the session for one client. Returns a failure description, or
   /// `nil` on success. Claiming twice is harmless.
   func claim(_ client: Client) -> String? {
      claimants.insert(client)
      guard !isActive else { return nil }

      do {
         let session = AVAudioSession.sharedInstance()

         // `.voicePrompt` is the mode Apple built for navigation cues: it
         // ducks rather than interrupts, and routes sensibly over CarPlay and
         // Bluetooth. Radar tones ride the same configuration — they are
         // safety prompts, not media.
         try session.setCategory(
            .playback,
            mode: .voicePrompt,
            options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
         )
         try session.setActive(true)
         isActive = true
         return nil
      } catch {
         claimants.remove(client)
         return error.localizedDescription
      }
   }

   /// Releases one client's claim. The system session is handed back — and the
   /// rider's music un-ducked — only when no claimant remains.
   func release(_ client: Client) -> String? {
      claimants.remove(client)
      guard isActive, claimants.isEmpty else { return nil }

      isActive = false

      do {
         try AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
         )
         return nil
      } catch {
         return error.localizedDescription
      }
   }
}
