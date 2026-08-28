//
//  BigVWatchApp.swift
//  BigV Watch App
//

import SwiftUI

/// The Watch composition root.
///
/// Builds the one view model and hands it down, the same way `BigVApp` does on the
/// phone. The Watch is a body sensor and a remote: it owns no store, no location
/// stream and no ride.
@main
struct BigVWatchApp: App {

   // MARK: - Object Graph

   @State private var rideWatchViewModel = RideWatchViewModel()

   // MARK: - Scene

   var body: some Scene {
      WindowGroup {
         RideWatchDashboardView(rideWatchViewModel: rideWatchViewModel)
      }
   }
}
