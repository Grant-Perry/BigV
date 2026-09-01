//
//  RideSplashVideoFill.swift
//  BigV
//

import AVFoundation
import SwiftUI
import UIKit

/// Full-bleed muted splash clip. No system playback chrome.
struct RideSplashVideoFill: UIViewRepresentable {

   let player: AVPlayer

   func makeUIView(context: Context) -> PlayerView {
      let view = PlayerView()
      view.isUserInteractionEnabled = false
      view.playerLayer.player = player
      view.playerLayer.videoGravity = .resizeAspectFill
      return view
   }

   func updateUIView(_ uiView: PlayerView, context: Context) {
      uiView.playerLayer.player = player
   }

   final class PlayerView: UIView {
      override class var layerClass: AnyClass { AVPlayerLayer.self }
      var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
   }
}
