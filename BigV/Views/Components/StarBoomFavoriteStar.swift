//
//  StarBoomFavoriteStar.swift
//  BigV
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - StarBoom

/// Reusable ~1s “sticky saved” celebration: coordinated haptics + phase callbacks.
enum StarBoom {

   enum CelebrationPhase: Sendable {
      case appear
      case burst
      case settling
      case complete
   }

   static let durationSeconds: Double = 1.0

   @MainActor
   static func runCelebration(onPhase: @escaping @MainActor (CelebrationPhase) -> Void) async {
      onPhase(.appear)
      lightImpact()
      try? await Task.sleep(for: .milliseconds(150))
      onPhase(.burst)
      mediumImpact()
      try? await Task.sleep(for: .milliseconds(300))
      onPhase(.settling)
      try? await Task.sleep(for: .milliseconds(300))
      onPhase(.complete)
      lightImpact()
      try? await Task.sleep(for: .milliseconds(250))
   }

   @MainActor
   private static func lightImpact() {
      #if os(iOS)
      let generator = UIImpactFeedbackGenerator(style: .light)
      generator.prepare()
      generator.impactOccurred()
      #endif
   }

   @MainActor
   private static func mediumImpact() {
      #if os(iOS)
      let generator = UIImpactFeedbackGenerator(style: .medium)
      generator.prepare()
      generator.impactOccurred()
      #endif
   }
}

// MARK: - StarBoomFavoriteStar

/// Favorite star that briefly blooms yellow/green when `boomTrigger` advances.
///
/// Parent increments `boomTrigger` first, then toggles favorite state — same
/// contract as BigFli's `StarBoomChevron`.
struct StarBoomFavoriteStar: View {

   let isFavorite: Bool
   let boomTrigger: Int
   var font: Font = .title3.weight(.semibold)

   @Environment(\.accessibilityReduceMotion) private var reduceMotion
   @State private var showBurst = false
   @State private var burstScale: CGFloat = 1.0
   @State private var glowOpacity: CGFloat = 0
   @State private var isAnimating = false
   @State private var lastProcessedTrigger = -1

   var body: some View {
      ZStack {
         Group {
            if isFavorite {
               Image(systemName: "star.fill")
                  .foregroundStyle(
                     LinearGradient(
                        colors: [.gpYellow, .gpGreen],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                     )
                  )
            } else {
               Image(systemName: "star")
                  .foregroundStyle(.white.opacity(0.55))
            }
         }
         .font(font)
         .opacity(showBurst ? 0.15 : 1)

         Image(systemName: "star.fill")
            .font(font)
            .foregroundStyle(
               LinearGradient(
                  colors: [.gpYellow, .gpGreen],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
               )
            )
            .scaleEffect(burstScale)
            .opacity(showBurst ? 1 : 0)
            .shadow(color: Color.gpGreen.opacity(glowOpacity), radius: 8 + glowOpacity * 8)
            .shadow(color: Color.gpYellow.opacity(glowOpacity * 0.9), radius: 6 + glowOpacity * 6)
      }
      .frame(width: 34, height: 34)
      .contentShape(.rect)
      .onChange(of: boomTrigger) { _, newValue in
         guard newValue != lastProcessedTrigger else { return }
         lastProcessedTrigger = newValue
         Task { await runCelebration() }
      }
   }

   @MainActor
   private func runCelebration() async {
      guard !isAnimating else { return }
      isAnimating = true
      defer { isAnimating = false }

      if reduceMotion {
         showBurst = true
         burstScale = 1.15
         glowOpacity = 0.7
         try? await Task.sleep(for: .milliseconds(280))
         withAnimation(.easeOut(duration: 0.18)) {
            showBurst = false
            burstScale = 1.0
            glowOpacity = 0
         }
         return
      }

      await StarBoom.runCelebration { phase in
         switch phase {
            case .appear:
               showBurst = true
               burstScale = 1.0
               glowOpacity = 0.35
               withAnimation(.easeOut(duration: 0.14)) {
                  glowOpacity = 0.95
               }
            case .burst:
               withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) {
                  burstScale = 1.65
                  glowOpacity = 1.0
               }
            case .settling:
               withAnimation(.easeOut(duration: 0.28)) {
                  burstScale = 1.0
                  glowOpacity = 0.12
               }
            case .complete:
               withAnimation(.easeOut(duration: 0.24)) {
                  showBurst = false
                  glowOpacity = 0
               }
         }
      }
   }
}

// MARK: - StarBoomChevron

/// Chevron that briefly becomes a star when `boomTrigger` advances — the BigFli
/// section header pattern reused for the favorites disclosure.
struct StarBoomChevron: View {

   let isExpanded: Bool
   let boomTrigger: Int
   var font: Font = .caption.weight(.bold)
   var foregroundColor: Color = .secondary

   @Environment(\.accessibilityReduceMotion) private var reduceMotion
   @State private var showStar = false
   @State private var starScale: CGFloat = 1.0
   @State private var glowOpacity: CGFloat = 0
   @State private var isAnimating = false
   @State private var lastProcessedTrigger = -1

   var body: some View {
      ZStack {
         Image(systemName: "chevron.right")
            .font(font)
            .foregroundStyle(foregroundColor)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
            .opacity(showStar ? 0 : 1)

         Image(systemName: "star.fill")
            .font(font)
            .foregroundStyle(
               LinearGradient(
                  colors: [.gpYellow, .gpGreen],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
               )
            )
            .scaleEffect(starScale)
            .opacity(showStar ? 1 : 0)
            .shadow(color: Color.gpGreen.opacity(glowOpacity), radius: 8 + glowOpacity * 8)
            .shadow(color: Color.gpYellow.opacity(glowOpacity * 0.9), radius: 6 + glowOpacity * 6)
      }
      .frame(width: 22, height: 22)
      .contentShape(.rect)
      .onChange(of: boomTrigger) { _, newValue in
         guard newValue != lastProcessedTrigger else { return }
         lastProcessedTrigger = newValue
         Task { await runCelebration() }
      }
   }

   @MainActor
   private func runCelebration() async {
      guard !isAnimating else { return }
      isAnimating = true
      defer { isAnimating = false }

      if reduceMotion {
         showStar = true
         starScale = 1.15
         glowOpacity = 0.7
         try? await Task.sleep(for: .milliseconds(280))
         withAnimation(.easeOut(duration: 0.18)) {
            showStar = false
            starScale = 1.0
            glowOpacity = 0
         }
         return
      }

      await StarBoom.runCelebration { phase in
         switch phase {
            case .appear:
               showStar = true
               starScale = 1.0
               glowOpacity = 0.35
               withAnimation(.easeOut(duration: 0.14)) {
                  glowOpacity = 0.95
               }
            case .burst:
               withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) {
                  starScale = 1.65
                  glowOpacity = 1.0
               }
            case .settling:
               withAnimation(.easeOut(duration: 0.28)) {
                  starScale = 1.0
                  glowOpacity = 0.12
               }
            case .complete:
               withAnimation(.easeOut(duration: 0.24)) {
                  showStar = false
                  glowOpacity = 0
               }
         }
      }
   }
}
