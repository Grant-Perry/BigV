//
//  RideViewModel.swift
//  BigV
//

import Foundation
import SwiftData

/// Presents the live ride to SwiftUI and forwards rider intent to the session.
///
/// All unit conversion and string formatting happens here so views stay dumb and
/// the engine stays in SI units.
@Observable
@MainActor
final class RideViewModel {

   // MARK: - Dependencies

   private let rideSessionManager: RideSessionManager

   init(rideSessionManager: RideSessionManager = RideSessionManager()) {
      self.rideSessionManager = rideSessionManager
   }

   // MARK: - State

   private var state: RideState { rideSessionManager.state }

   var phase: RidePhase { state.phase }
   var isRecording: Bool { state.phase == .recording }
   var isPaused: Bool { state.phase == .paused }
   var isAcquiringGPS: Bool { state.phase == .acquiringGPS }
   var isFinished: Bool { state.phase == .finished }
   var isIdle: Bool { state.phase == .idle }
   var hasGPSFix: Bool { state.hasGPSFix }
   var isMoving: Bool { state.isMoving }

   // MARK: - Headline

   var speed: String {
      state.hasGPSFix ? RideFormatters.speed(state.speed) : RideFormatters.placeholder
   }

   var speedUnit: String { RideFormatters.Unit.speed }

   // MARK: - Metric Tiles

   var totals: RideTotals { RideTotals(state: state) }

   var distance: String { totals.distance }
   var distanceUnit: String { RideFormatters.Unit.distance }

   var rideTime: String { totals.rideTime }
   var movingTime: String { totals.movingTime }

   var elevationGain: String { totals.elevationGain }
   var elevationLoss: String { totals.elevationLoss }
   var elevationUnit: String { RideFormatters.Unit.elevation }

   var averageSpeed: String { totals.averageSpeed }
   var maximumSpeed: String { totals.maximumSpeed }

   var grade: String {
      state.hasGPSFix ? RideFormatters.grade(state.grade) : RideFormatters.placeholder
   }

   var gradeUnit: String { RideFormatters.Unit.grade }

   var heading: String {
      RideFormatters.cardinal(state.course) ?? RideFormatters.placeholder
   }

   // MARK: - Sensors

   /// `nil` until a Watch is feeding a pulse, which is also the signal the chip
   /// uses to stay off the dashboard entirely.
   var heartRate: String? {
      state.heartRate.map(RideFormatters.heartRate)
   }

   var heartRateUnit: String { RideFormatters.Unit.heartRate }

   // MARK: - Status

   var statusText: String {
      switch state.phase {
         case .idle: "Ready"
         case .acquiringGPS: "Acquiring GPS"
         case .recording: state.isMoving ? "Recording" : "Stopped"
         case .paused: "Paused"
         case .finished: "Ride complete"
      }
   }

   var accuracyText: String? {
      guard let accuracy = state.horizontalAccuracy else { return nil }
      return RideFormatters.accuracy(accuracy)
   }

   var issueMessage: String? { state.locationIssue?.message }

   // MARK: - Summary

   /// The ride the store committed, once finalization has landed.
   var finishedRideID: PersistentIdentifier? { rideSessionManager.finishedRideID }

   var healthKitStatusText: String? {
      switch state.healthKitExport {
         case .idle: nil
         case .exporting: "Saving to Apple Health…"
         case .saved: "Saved to Apple Health"
         case .denied: "Not shared with Apple Health"
         case .unavailable: "Apple Health unavailable"
         case .failed: "Apple Health save failed"
      }
   }

   var didSaveToHealthKit: Bool { state.healthKitExport == .saved }

   var storageWarning: String? {
      state.hasStorageFailure ? "Some ride data could not be saved" : nil
   }

   // MARK: - Intent

   func start() { rideSessionManager.start() }
   func pause() { rideSessionManager.pause() }
   func resume() { rideSessionManager.resume() }
   func end() { rideSessionManager.end() }
   func reset() { rideSessionManager.reset() }

   func startNewRide() {
      rideSessionManager.reset()
      rideSessionManager.start()
   }

   func flushPendingWork() { rideSessionManager.flushPendingWork() }
}
