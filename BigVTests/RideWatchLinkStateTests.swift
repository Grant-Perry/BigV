//
//  RideWatchLinkStateTests.swift
//  BigVTests
//

import Foundation
import Testing
import WatchConnectivity
@testable import BigV

/// Link health: five WatchConnectivity facts collapsing into one answer.
struct RideWatchLinkStateTests {

   // MARK: - Fixtures

   private func resolve(
      isSupported: Bool = true,
      activation: RideWatchActivation = .activated,
      isPaired: Bool = true,
      isCompanionAppInstalled: Bool = true,
      isReachable: Bool = true
   ) -> RideWatchLinkState {
      RideWatchLinkState.resolve(
         isSupported: isSupported,
         activation: activation,
         isPaired: isPaired,
         isCompanionAppInstalled: isCompanionAppInstalled,
         isReachable: isReachable
      )
   }

   // MARK: - Happy Path

   @Test func everythingHealthyResolvesToConnected() {
      #expect(resolve() == .connected)
   }

   @Test func aLinkedButSleepingCounterpartResolvesToUnreachable() {
      #expect(resolve(isReachable: false) == .unreachable)
   }

   // MARK: - Precedence

   @Test func anUnsupportedDeviceOutranksEverythingElse() {
      let state = resolve(
         isSupported: false,
         activation: .notActivated,
         isPaired: false,
         isCompanionAppInstalled: false,
         isReachable: false
      )

      #expect(state == .unsupported)
   }

   /// Pairing and installation are only meaningful once activation has finished,
   /// so an unactivated session reports activating rather than guessing.
   @Test(arguments: [RideWatchActivation.notActivated, .inactive])
   func anUnfinishedActivationOutranksPairing(activation: RideWatchActivation) {
      #expect(resolve(activation: activation, isPaired: false) == .activating)
   }

   @Test func anUnpairedPhoneOutranksInstallation() {
      #expect(resolve(isPaired: false, isCompanionAppInstalled: false) == .notPaired)
   }

   @Test func aPairedWatchWithoutTheAppSaysSo() {
      #expect(resolve(isCompanionAppInstalled: false) == .appNotInstalled)
   }

   @Test func reachabilityIsOnlyConsultedLast() {
      #expect(resolve(isPaired: false, isReachable: true) == .notPaired)
   }

   // MARK: - Capability

   @Test func onlyAConnectedLinkCarriesLiveMessages() {
      for state in RideWatchLinkState.allCases {
         #expect(state.allowsLiveMessages == (state == .connected))
      }
   }

   /// Unreachable still allows queued updates — the application context is exactly
   /// what survives it.
   @Test func queuedUpdatesSurviveUnreachability() {
      #expect(RideWatchLinkState.unreachable.allowsQueuedUpdates)
      #expect(RideWatchLinkState.connected.allowsQueuedUpdates)

      #expect(!RideWatchLinkState.unsupported.allowsQueuedUpdates)
      #expect(!RideWatchLinkState.activating.allowsQueuedUpdates)
      #expect(!RideWatchLinkState.notPaired.allowsQueuedUpdates)
      #expect(!RideWatchLinkState.appNotInstalled.allowsQueuedUpdates)
   }

   @Test func liveMessagesImplyQueuedUpdates() {
      for state in RideWatchLinkState.allCases where state.allowsLiveMessages {
         #expect(state.allowsQueuedUpdates)
      }
   }

   // MARK: - Presentation

   @Test func onlyAConnectedLinkStaysSilent() {
      #expect(RideWatchLinkState.connected.message == nil)

      for state in RideWatchLinkState.allCases where state != .connected {
         #expect(state.message != nil)
      }
   }

   // MARK: - Framework Bridge

   @Test func watchConnectivityActivationStatesMapAcross() {
      #expect(RideWatchActivation(.notActivated) == .notActivated)
      #expect(RideWatchActivation(.inactive) == .inactive)
      #expect(RideWatchActivation(.activated) == .activated)
   }
}
