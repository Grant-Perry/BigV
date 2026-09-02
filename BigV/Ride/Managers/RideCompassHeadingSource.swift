//
//  RideCompassHeadingSource.swift
//  BigV
//

import CoreLocation
import Foundation
import UIKit

/// Magnetometer heading for the cockpit.
///
/// GPS only knows a course while the bike is rolling, and the engine only
/// trusts it once accuracy is reported, so at a trailhead the ribbon had
/// nothing to point at. This fills that gap with the compass, the way the
/// Watch face does. Runs only while the dashboard is on screen; it is a
/// battery cost and useless in a pocket.
@Observable
@MainActor
final class RideCompassHeadingSource: NSObject, CLLocationManagerDelegate {

   /// Degrees true when declination is known, magnetic otherwise. Negative
   /// means unknown — no magnetometer, not running, or not yet calibrated.
   private(set) var heading: Double = -1

   private let manager = CLLocationManager()
   private var isRunning = false

   override init() {
      super.init()
      manager.delegate = self
      manager.headingFilter = 1.5
   }

   var isAvailable: Bool { CLLocationManager.headingAvailable() }

   func start() {
      guard !isRunning, isAvailable else { return }
      isRunning = true
      manager.headingOrientation = Self.deviceOrientation
      manager.startUpdatingHeading()
      DebugPrint(mode: .sessionLifecycle, "Compass heading started")
   }

   func stop() {
      guard isRunning else { return }
      isRunning = false
      manager.stopUpdatingHeading()
      heading = -1
      DebugPrint(mode: .sessionLifecycle, "Compass heading stopped")
   }

   // MARK: - CLLocationManagerDelegate

   nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
      let trueHeading = newHeading.trueHeading
      let magneticHeading = newHeading.magneticHeading
      let accuracy = newHeading.headingAccuracy

      MainActor.assumeIsolated {
         apply(trueHeading: trueHeading, magneticHeading: magneticHeading, accuracy: accuracy)
      }
   }

   /// A calibration prompt mid-ride is worse than a wobbly needle.
   nonisolated func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
      false
   }

   private func apply(trueHeading: Double, magneticHeading: Double, accuracy: Double) {
      guard isRunning else { return }

      // Negative accuracy is Core Location's "invalid"; drop it rather than
      // swing the ribbon on noise.
      guard accuracy >= 0 else { return }

      // Keep the reading square with the screen after a rotation.
      manager.headingOrientation = Self.deviceOrientation

      heading = trueHeading >= 0 ? trueHeading : magneticHeading
   }

   // MARK: - Orientation

   private static var deviceOrientation: CLDeviceOrientation {
      switch UIDevice.current.orientation {
         case .landscapeLeft: .landscapeLeft
         case .landscapeRight: .landscapeRight
         case .portraitUpsideDown: .portraitUpsideDown
         default: .portrait
      }
   }
}
