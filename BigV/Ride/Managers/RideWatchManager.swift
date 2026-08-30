//
//  RideWatchManager.swift
//  BigV
//

import Foundation
import WatchConnectivity

/// The phone's end of the wrist link.
///
/// Owns `WCSession`, mirrors the ride out to the Watch, and turns everything the
/// Watch sends back into an `AsyncStream` of domain events. It never touches
/// `RideState`: heart rate and remote commands are handed to `RideSessionManager`,
/// which stays the only type in BigV allowed to publish a ride.
///
/// ## Transport
///
/// Two channels, chosen per payload rather than per direction:
///
/// - `sendMessage` is the live channel. It needs reachability and delivers in
///   milliseconds, so it carries the 1 Hz ride mirror and remote commands, where
///   latency is the entire point.
/// - `updateApplicationContext` is the latest-state-wins channel. It survives
///   unreachability, coalesces to a single slot, and is readable the instant the
///   Watch app launches. It carries phase changes and a slow metrics heartbeat so
///   a Watch that was asleep, out of range, or freshly opened mid-ride comes up
///   already knowing the truth instead of waiting for the next tick.
@Observable
@MainActor
final class RideWatchManager {

   // MARK: - Events

   /// What the Watch can cause on the phone. Deliberately narrow: a body sensor
   /// and four buttons.
   enum Event: Sendable {

      /// A fresh, plausible reading, or `nil` when the wrist stopped sensing.
      case heartRate(Double?)

      case command(RideRemoteCommandRequest, RideRemoteCommandAcknowledgement)
   }

   // MARK: - Published State

   private(set) var linkState: RideWatchLinkState = .activating

   // MARK: - Private Properties

   private var session: WCSession?
   private var relay: RideWatchConnectivityRelay?
   private var relayTask: Task<Void, Never>?

   private var eventContinuation: AsyncStream<Event>.Continuation?

   /// Held so escaping WatchConnectivity error handlers have a thread-safe way to
   /// report back without capturing the manager or logging off the main actor.
   private var relayContinuation: AsyncStream<RideWatchConnectivityEvent>.Continuation?

   private var lastContextPublishedAt: Date?
   private var lastContextPhase: RidePhase?

   /// How often the metrics heartbeat refreshes the application context. Phase
   /// changes ignore this and go immediately.
   private let contextInterval: TimeInterval = 5

   // MARK: - Activation

   /// Opens the link and returns the events the ride session should act on.
   ///
   /// Called once at launch, not per ride: START has to work from the wrist while
   /// the phone is idle in a pocket.
   func activate() -> AsyncStream<Event> {
      shutDown()

      let (stream, eventContinuation) = AsyncStream<Event>.makeStream(
         bufferingPolicy: .bufferingNewest(32)
      )
      self.eventContinuation = eventContinuation

      guard WCSession.isSupported() else {
         linkState = .unsupported
         eventContinuation.finish()
         DebugPrint(mode: .sensors, "WatchConnectivity unsupported on this device")
         return stream
      }

      let (relayStream, relayContinuation) = AsyncStream<RideWatchConnectivityEvent>.makeStream(
         bufferingPolicy: .bufferingNewest(32)
      )
      self.relayContinuation = relayContinuation

      let relay = RideWatchConnectivityRelay(continuation: relayContinuation)
      self.relay = relay

      let session = WCSession.default
      session.delegate = relay
      session.activate()
      self.session = session

      relayTask = Task { [weak self] in
         for await event in relayStream {
            guard let self else { return }
            self.handle(event)
         }
      }

      refreshLinkState()
      DebugPrint(mode: .sensors, "Watch link activating")

      return stream
   }

   func shutDown() {
      relayTask?.cancel()
      relayTask = nil

      relay?.finish()
      relay = nil

      relayContinuation = nil

      eventContinuation?.finish()
      eventContinuation = nil

      session = nil
      lastContextPublishedAt = nil
      lastContextPhase = nil
   }

   // MARK: - Publishing

   /// Mirrors the ride to the wrist. Cheap enough to call every second.
   func publish(_ snapshot: RideWatchMetricsSnapshot) {
      guard let session,
            session.activationState == .activated,
            linkState.allowsQueuedUpdates
      else { return }

      let payload = RideWatchMessage.metrics(snapshot).payload

      if linkState.allowsLiveMessages, session.isReachable {
         let failures = relayContinuation

         // `@Sendable` keeps Swift from inferring this Objective-C closure as
         // `@MainActor` under main-actor default isolation. WatchConnectivity
         // invokes it on its own queue, and the isolation check that inference
         // installs would trap the moment a mirror failed to send.
         session.sendMessage(payload, replyHandler: nil) { @Sendable error in
            failures?.yield(.deliveryFailed("Mirror send failed: \(error.localizedDescription)"))
         }
      }

      guard shouldRefreshContext(for: snapshot) else { return }

      do {
         try session.updateApplicationContext(payload)
         lastContextPublishedAt = .now
         lastContextPhase = snapshot.phase
      } catch {
         DebugPrint(mode: .sensors, "Application context update failed: \(error.localizedDescription)")
      }
   }

   /// A phase change is the one thing the Watch must never miss, so it bypasses
   /// the heartbeat interval entirely.
   private func shouldRefreshContext(for snapshot: RideWatchMetricsSnapshot) -> Bool {
      guard lastContextPhase == snapshot.phase else { return true }
      guard let lastContextPublishedAt else { return true }

      return Date.now.timeIntervalSince(lastContextPublishedAt) >= contextInterval
   }

   // MARK: - Event Handling

   private func handle(_ event: RideWatchConnectivityEvent) {
      switch event {
         case .linkChanged:
            refreshLinkState()
            seedFromWatchContext()

         case .needsReactivation:
            session?.activate()
            refreshLinkState()
            DebugPrint(mode: .sensors, "Watch link reactivating after Watch switch")

         case .received(let message):
            apply(message, reply: .unanswerable)

         case .receivedAnswerable(let message, let reply):
            apply(message, reply: reply)

         case .deliveryFailed(let reason):
            DebugPrint(mode: .sensors, limit: 20, "Watch link: \(reason)")
      }
   }

   private func apply(_ message: RideWatchMessage, reply: RideWatchReplyBox) {
      switch message {
         case .heartRate(let reading):
            guard reading.isPlausible, reading.isFresh(within: 20) else {
               DebugPrint(
                  mode: .sensors,
                  limit: 20,
                  "Discarded heart rate \(reading.beatsPerMinute) from \(reading.measuredAt)"
               )
               return
            }
            eventContinuation?.yield(.heartRate(reading.beatsPerMinute))

         case .heartRateEnded:
            eventContinuation?.yield(.heartRate(nil))

         case .command(let request):
            let acknowledgement = RideRemoteCommandAcknowledgement { outcome, phase in
               reply(.commandReceipt(RideRemoteCommandReceipt(outcome: outcome, phase: phase)))
            }
            eventContinuation?.yield(.command(request, acknowledgement))

         case .metrics, .commandReceipt:
            // Phone-authored. Seeing one come back means the two builds disagree
            // about who owns the ride, which is worth a line in the log.
            DebugPrint(mode: .sensors, "Ignored phone-authored message echoed from the Watch")
      }
   }

   // MARK: - Seeding

   /// The Watch writes its latest pulse into its own application context so a
   /// phone that was killed, pocketed, or unreachable still comes up with a beat
   /// instead of an empty chip.
   private func seedFromWatchContext() {
      guard let session, session.activationState == .activated else { return }

      let context = session.receivedApplicationContext
      guard !context.isEmpty,
            let message = RideWatchMessage(payload: context)
      else { return }

      apply(message, reply: .unanswerable)
   }

   // MARK: - Link State

   private func refreshLinkState() {
      guard let session else {
         linkState = .unsupported
         return
      }

      // Pairing, installation and reachability are undefined until activation
      // finishes. Reading them early is what prints "WCSession has not been
      // activated" and "counterpart app not installed" on every launch.
      let activation = RideWatchActivation(session.activationState)
      guard activation == .activated else {
         applyLinkState(.activating)
         return
      }

      // Never read `isWatchAppInstalled`. WCSession logs "counterpart app not
      // installed" and then lies after a companion install from Xcode, which
      // blocked every publish to a Watch the rider was already using.
      applyLinkState(
         RideWatchLinkState.resolve(
            isSupported: true,
            activation: activation,
            isPaired: session.isPaired,
            isCompanionAppInstalled: session.isPaired,
            isReachable: session.isReachable
         )
      )
   }

   private func applyLinkState(_ resolved: RideWatchLinkState) {
      guard resolved != linkState else { return }

      linkState = resolved

      // A link that just went quiet leaves the mirror stale, so the next publish
      // has to refresh the context rather than wait out the heartbeat.
      lastContextPublishedAt = nil

      DebugPrint(mode: .sensors, "Watch link: \(resolved.rawValue)")
   }
}
