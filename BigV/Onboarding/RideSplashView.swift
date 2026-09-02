//
//  RideSplashView.swift
//  BigV
//

import AVFoundation
import SwiftUI
import UIKit

/// Branded splash after the void system launch screen.
///
/// Plays the 5-second trail clip with BigVelo superimposed. A tap skips
/// immediately. Reduce Motion holds the still plate and the wordmark only.
struct RideSplashView: View {

   var onFinished: () -> Void

   @Environment(\.accessibilityReduceMotion) private var reduceMotion
   @State private var isVisible = false
   @State private var player: AVPlayer?
   @State private var hasFinished = false

   private let stillHoldNanoseconds: UInt64 = 1_800_000_000

   var body: some View {
      ZStack {
         RideDashboardTheme.void

         plate
            .opacity(isVisible ? 1 : (reduceMotion ? 0 : 0.85))
            .scaleEffect(reduceMotion || isVisible ? 1 : 1.04)
            .allowsHitTesting(false)

         wordmark
            .opacity(isVisible ? 1 : 0)
            .allowsHitTesting(false)
      }
      .ignoresSafeArea()
      .contentShape(.rect)
      .onTapGesture(perform: finish)
      .accessibilityAddTraits(.isButton)
      .accessibilityLabel("BigVelo")
      .accessibilityHint("Skips the splash")
      .preferredColorScheme(.dark)
      .task {
         withAnimation(reduceMotion ? .easeOut(duration: 0.35) : .easeOut(duration: 0.55)) {
            isVisible = true
         }
         await playThenFinish()
      }
   }

   // MARK: - Wordmark

   private var wordmark: some View {
      VStack(spacing: 16) {
         Spacer()

         RideWordmark(pointSize: 68)
            .minimumScaleFactor(0.7)
            .lineLimit(1)

         Spacer()
         Spacer()
      }
      .padding(.horizontal, 24)
   }

   // MARK: - Plate

   @ViewBuilder
   private var plate: some View {
      if let player, !reduceMotion {
         RideSplashVideoFill(player: player)
            .overlay {
               LinearGradient(
                  colors: [
                     RideDashboardTheme.void.opacity(0.28),
                     RideDashboardTheme.void.opacity(0.08),
                     RideDashboardTheme.void.opacity(0.45)
                  ],
                  startPoint: .top,
                  endPoint: .bottom
               )
            }
      } else if UIImage(named: RideOnboardingArt.splash) != nil {
         Image(RideOnboardingArt.splash)
            .resizable()
            .scaledToFill()
            .overlay {
               LinearGradient(
                  colors: [
                     RideDashboardTheme.void.opacity(0.55),
                     RideDashboardTheme.void.opacity(0.25),
                     RideDashboardTheme.void.opacity(0.82)
                  ],
                  startPoint: .top,
                  endPoint: .bottom
               )
            }
      } else {
         RideAtmosphereBackground(scene: .speedCluster)
      }
   }

   // MARK: - Playback

   private func playThenFinish() async {
      if !reduceMotion, let url = Bundle.main.url(forResource: "OnboardSplash", withExtension: "mp4") {
         let item = AVPlayerItem(url: url)
         let splashPlayer = AVPlayer(playerItem: item)
         splashPlayer.isMuted = true
         player = splashPlayer
         splashPlayer.play()
         await withTaskGroup(of: Void.self) { group in
            group.addTask { await Self.waitForEnd(of: item) }
            group.addTask {
               try? await Task.sleep(for: .seconds(6.2))
            }
            await group.next()
            group.cancelAll()
         }
      } else {
         try? await Task.sleep(for: .nanoseconds(stillHoldNanoseconds))
      }
      guard !Task.isCancelled else { return }
      finish()
   }

   private func finish() {
      guard !hasFinished else { return }
      hasFinished = true
      player?.pause()
      player = nil
      onFinished()
   }

   private static func waitForEnd(of item: AVPlayerItem) async {
      let box = EndContinuationBox()
      await withTaskCancellationHandler {
         await withCheckedContinuation { continuation in
            box.store(continuation)
            box.attach(
               NotificationCenter.default.addObserver(
                  forName: .AVPlayerItemDidPlayToEndTime,
                  object: item,
                  queue: .main
               ) { _ in
                  box.resume()
               }
            )
         }
      } onCancel: {
         box.resume()
      }
   }
}

/// Resumes the end-of-clip wait once, from the player, a timeout, or a skip.
nonisolated private final class EndContinuationBox: @unchecked Sendable {

   private let lock = NSLock()
   private var continuation: CheckedContinuation<Void, Never>?
   private var token: NSObjectProtocol?

   func store(_ continuation: CheckedContinuation<Void, Never>) {
      lock.lock()
      self.continuation = continuation
      lock.unlock()
   }

   func attach(_ token: NSObjectProtocol) {
      lock.lock()
      self.token = token
      lock.unlock()
   }

   func resume() {
      lock.lock()
      let continuation = continuation
      self.continuation = nil
      let observer = token
      token = nil
      lock.unlock()

      if let observer {
         NotificationCenter.default.removeObserver(observer)
      }
      continuation?.resume()
   }
}

#Preview {
   RideSplashView(onFinished: {})
}
