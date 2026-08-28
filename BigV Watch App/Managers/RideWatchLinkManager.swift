//
//  RideWatchLinkManager.swift
//  BigV Watch App
//

import Foundation
import WatchConnectivity

/// The wrist's end of the link.
///
/// Sends heart rate and lifecycle requests to the phone, and streams back what
/// the phone says about the ride. Holds no ride truth of its own — everything it
/// receives is a snapshot the phone authored.
///
/// ## Transport
///
/// - **Heart rate** goes out over `sendMessage`, live only. A pulse the phone
///   receives after the fact has nothing to show, so when the phone is
///   unreachable the reading is dropped rather than queued. Nothing is lost: the
///   phone does not persist heart rate, it displays it.
/// - **Commands** go out over `sendMessage` when the phone is reachable, so the
///   rider gets a receipt in milliseconds. When it is not, they fall back to
///   `transferUserInfo`, which is queued, ordered and survives unreachability —
///   safe because every command carries a timestamp and the phone expires any
///   that arrive too late to still mean what the rider meant.
@MainActor
final class RideWatchLinkManager {

   // MARK: - Events

   enum Event: Sendable {
      case linkChanged(RideWatchLinkState)
      case metrics(RideWatchMetricsSnapshot)
      case receipt(RideRemoteCommandReceipt)

      /// A command could not be handed over live. It may still be queued.
      case commandUndelivered
   }

   // MARK: - Private Properties

   private var session: WCSession?
   private var relay: RideWatchConnectivityRelay?
   private var relayTask: Task<Void, Never>?

   private var eventContinuation: AsyncStream<Event>.Continuation?
   private var relayContinuation: AsyncStream<RideWatchConnectivityEvent>.Continuation?

   private var linkState: RideWatchLinkState = .activating
   private var hasSeededFromContext = false

   // MARK: - Activation

   func activate() -> AsyncStream<Event> {
      shutDown()

      let (stream, eventContinuation) = AsyncStream<Event>.makeStream(
         bufferingPolicy: .bufferingNewest(32)
      )
      self.eventContinuation = eventContinuation

      guard WCSession.isSupported() else {
         linkState = .unsupported
         eventContinuation.yield(.linkChanged(.unsupported))
         eventContinuation.finish()
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
      hasSeededFromContext = false
   }

   // MARK: - Sending

   func send(_ command: RideRemoteCommand) {
      let request = RideRemoteCommandRequest(command: command)
      let payload = RideWatchMessage.command(request).payload

      guard let session else {
         eventContinuation?.yield(.commandUndelivered)
         return
      }

      guard linkState.allowsLiveMessages else {
         queue(payload, for: command, on: session)
         return
      }

      let events = eventContinuation

      session.sendMessage(payload, replyHandler: { reply in
         guard let message = RideWatchMessage(payload: reply),
               case .commandReceipt(let receipt) = message
         else { return }

         events?.yield(.receipt(receipt))
      }, errorHandler: { _ in
         events?.yield(.commandUndelivered)
      })

      DebugPrint(mode: .sessionLifecycle, "Sent \(command.rawValue) live")
   }

   /// Hands a command to the background queue when the phone is out of reach.
   ///
   /// Reported as undelivered either way: the rider is told it did not land now,
   /// and if it does land in time the mirrored phase corrects the screen a moment
   /// later.
   private func queue(_ payload: [String: Any], for command: RideRemoteCommand, on session: WCSession) {
      guard linkState.allowsQueuedUpdates else {
         eventContinuation?.yield(.commandUndelivered)
         return
      }

      session.transferUserInfo(payload)
      eventContinuation?.yield(.commandUndelivered)

      DebugPrint(mode: .sessionLifecycle, "Queued \(command.rawValue) for an unreachable phone")
   }

   func report(_ reading: RideWatchHeartRateReading) {
      guard let session, linkState.allowsLiveMessages else { return }

      let failures = relayContinuation
      session.sendMessage(RideWatchMessage.heartRate(reading).payload, replyHandler: nil) { error in
         failures?.yield(.deliveryFailed("Heart rate send failed: \(error.localizedDescription)"))
      }
   }

   func reportHeartRateEnded() {
      guard let session, linkState.allowsLiveMessages else { return }

      let failures = relayContinuation
      session.sendMessage(RideWatchMessage.heartRateEnded.payload, replyHandler: nil) { error in
         failures?.yield(.deliveryFailed("Heart rate stop failed: \(error.localizedDescription)"))
      }
   }

   // MARK: - Event Handling

   private func handle(_ event: RideWatchConnectivityEvent) {
      switch event {
         case .linkChanged:
            refreshLinkState()
            seedFromApplicationContext()

         case .needsReactivation:
            session?.activate()
            refreshLinkState()

         case .received(let message), .receivedAnswerable(let message, _):
            apply(message)

         case .deliveryFailed(let reason):
            DebugPrint(mode: .sensors, limit: 20, "Phone link: \(reason)")
      }
   }

   private func apply(_ message: RideWatchMessage) {
      switch message {
         case .metrics(let snapshot):
            eventContinuation?.yield(.metrics(snapshot))

         case .commandReceipt(let receipt):
            eventContinuation?.yield(.receipt(receipt))

         case .heartRate, .heartRateEnded, .command:
            // Watch-authored. Seeing one come back means the two builds disagree.
            DebugPrint(mode: .sensors, "Ignored Watch-authored message echoed from the phone")
      }
   }

   // MARK: - Seeding

   /// Reads the phone's last application context once activation completes.
   ///
   /// This is what makes opening the Watch app mid-ride land on a live dashboard
   /// instead of an idle one: the newest snapshot is already sitting in the
   /// context slot, with no message in flight and no reachability required.
   private func seedFromApplicationContext() {
      guard !hasSeededFromContext,
            let session,
            session.activationState == .activated
      else { return }

      hasSeededFromContext = true

      guard let message = RideWatchMessage(payload: session.receivedApplicationContext),
            case .metrics(let snapshot) = message
      else { return }

      eventContinuation?.yield(.metrics(snapshot))
      DebugPrint(mode: .sessionLifecycle, "Seeded from phone context: \(snapshot.phase.rawValue)")
   }

   // MARK: - Link State

   /// The Watch cannot see pairing or installation — those are iOS-only facts, and
   /// a running Watch app is proof enough of both. Reachability is the real signal.
   private func refreshLinkState() {
      guard let session else {
         linkState = .unsupported
         eventContinuation?.yield(.linkChanged(.unsupported))
         return
      }

      let resolved = RideWatchLinkState.resolve(
         isSupported: true,
         activation: RideWatchActivation(session.activationState),
         isPaired: true,
         isCompanionAppInstalled: true,
         isReachable: session.isReachable
      )

      guard resolved != linkState else { return }

      linkState = resolved
      eventContinuation?.yield(.linkChanged(resolved))

      DebugPrint(mode: .sensors, "Phone link: \(resolved.rawValue)")
   }
}
