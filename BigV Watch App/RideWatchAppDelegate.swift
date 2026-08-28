//
//  RideWatchAppDelegate.swift
//  BigV Watch App
//

import HealthKit
import WatchKit

/// Receives the system workout launch. Without this, `startActivity()`
/// backgrounds the glance and leaves the rider on the clock until they
/// reopen the app by hand.
final class RideWatchAppDelegate: NSObject, WKApplicationDelegate {

   func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
      Task { @MainActor in
         await RideWatchRuntime.viewModel.handleWorkoutLaunch()
      }
   }
}
