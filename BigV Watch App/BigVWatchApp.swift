//
//  BigVWatchApp.swift
//  BigV Watch App
//

import SwiftUI

/// Survives the WindowGroup being torn down when watchOS dumps the glance
/// to the clock. `@State` on the `App` would mint a new view model on reopen
/// and park the sensor as if the ride had never started.
@MainActor
enum RideWatchRuntime {
   static let viewModel = RideWatchViewModel()
}

/// The Watch composition root.
///
/// Hands down the one view model, the same way `BigVApp` does on the phone.
/// The Watch is a body sensor and a remote: it owns no store, no location
/// stream and no ride.
@main
struct BigVWatchApp: App {

   @WKApplicationDelegateAdaptor(RideWatchAppDelegate.self) private var appDelegate

   var body: some Scene {
      WindowGroup {
         RideWatchDashboardView(rideWatchViewModel: RideWatchRuntime.viewModel)
      }
   }
}
