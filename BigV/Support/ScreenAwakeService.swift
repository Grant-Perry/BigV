//
//  ScreenAwakeService.swift
//  BigV
//

import UIKit

/// Keeps the display awake while the phone is acting as a bike computer.
@MainActor
enum ScreenAwakeService {

   static func setKeepAwake(_ keepAwake: Bool) {
      guard UIApplication.shared.isIdleTimerDisabled != keepAwake else { return }
      UIApplication.shared.isIdleTimerDisabled = keepAwake
      DebugPrint(mode: .sessionLifecycle, "Idle timer disabled: \(keepAwake)")
   }
}
