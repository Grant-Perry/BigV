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
   private let rideRadarSettings: RideRadarSettings
   private let rideUnitsSettings: RideUnitsSettings

   init(
      rideSessionManager: RideSessionManager = RideSessionManager(),
      rideRadarSettings: RideRadarSettings = RideRadarSettings(),
      rideUnitsSettings: RideUnitsSettings = RideUnitsSettings()
   ) {
      self.rideSessionManager = rideSessionManager
      self.rideRadarSettings = rideRadarSettings
      self.rideUnitsSettings = rideUnitsSettings
   }

   // MARK: - Units

   /// Read through the observable settings so every formatted figure
   /// re-renders the moment the rider changes systems in setup.
   var unitSystem: RideUnitSystem { rideUnitsSettings.system }

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
      state.hasGPSFix ? RideFormatters.speed(state.speed, system: unitSystem) : RideFormatters.placeholder
   }

   var speedUnit: String { unitSystem.speedUnit }

   // MARK: - Metric Tiles

   var totals: RideTotals { RideTotals(state: state, system: unitSystem) }

   var distance: String { totals.distance }
   var distanceUnit: String { unitSystem.distanceUnit }

   var rideTime: String { totals.rideTime }
   var movingTime: String { totals.movingTime }

   var elevationGain: String { totals.elevationGain }
   var elevationLoss: String { totals.elevationLoss }
   var elevationUnit: String { unitSystem.elevationUnit }

   var averageSpeed: String { totals.averageSpeed }
   var maximumSpeed: String { totals.maximumSpeed }

   var grade: String {
      state.hasGPSFix ? RideFormatters.grade(state.grade) : RideFormatters.placeholder
   }

   var gradeUnit: String { RideFormatters.Unit.grade }

   var course: Double { state.course }

   var heading: String {
      RideFormatters.cardinal(state.course) ?? RideFormatters.placeholder
   }

   var headingDegrees: String {
      RideFormatters.headingDegrees(state.course) ?? RideFormatters.placeholder
   }

   // MARK: - Sensors

   /// `nil` until a Watch is feeding a pulse, which is also the signal the chip
   /// uses to stay off the dashboard entirely.
   var heartRate: String? {
      state.heartRate.map(RideFormatters.heartRate)
   }

   var heartRateUnit: String { RideFormatters.Unit.heartRate }

   var heartRateBeatsPerMinute: Double? { state.heartRate }

   // MARK: - Radar

   var radar: RideRadarSnapshot { state.radar }

   /// Whether radar chrome belongs on screen at all. No pairing, no simulator,
   /// or the feature switched off → no empty rails anywhere.
   var isRadarAvailable: Bool { rideSessionManager.isRadarDisplayAvailable }

   /// The tape only earns its gutter while the link can still produce pips. A
   /// radar that is off, out of range, or done retrying hands the width back to
   /// the cockpit; the status-row chip keeps carrying the OFF state, so nothing
   /// is hidden from the rider.
   var showsRadarTape: Bool { isRadarAvailable && radarConnection != .disconnected }

   /// The tape dims when the link is down or the ride is paused — present but
   /// visibly not live, matching the speed hero's treatment.
   var isRadarDimmed: Bool { !state.radar.isConnected || isPaused }

   var radarSide: RideRadarSide { rideRadarSettings.side }

   var radarTracks: [RideRadarTracker.Track] { state.radar.tracks }
   var radarTier: RideRadarThreatTier? { state.radar.aggregateTier }
   var isRadarConnected: Bool { state.radar.isConnected }
   var radarConnection: RideRadarConnectionState { state.radar.connection }
   var radarVehicleCount: Int { state.radar.tracks.count }
   var radarPassCount: Int { state.radar.vehiclePassCount }

   var radarNearestDistance: String? {
      state.radar.nearestDistanceMeters.map {
         RideFormatters.radarDistance($0, system: unitSystem)
      }
   }

   /// Closing speed of the nearest vehicle in the app's display unit.
   var radarClosingSpeed: String? {
      guard let closing = state.radar.nearestClosingSpeedMetersPerSecond,
            closing > 0
      else { return nil }
      return RideFormatters.speed(closing, system: unitSystem)
   }

   var radarBattery: String? {
      state.radar.batteryPercent.map { "\($0)%" }
   }

   var radarIssueMessage: String? { state.radar.issue?.message }

   /// Monotonic alert edges for `.sensoryFeedback` and the edge-tint overlay.
   var radarAlertPulse: Int { state.radar.alertPulse }
   var radarClearPulse: Int { state.radar.clearPulse }

   var radarAlertHapticsEnabled: Bool { rideRadarSettings.alertHapticsEnabled }
   var radarOverlayEnabled: Bool { rideRadarSettings.overlayEnabled }

   // MARK: - Status

   var statusText: String {
      switch state.phase {
         case .idle: "Ready"
         case .acquiringGPS: "Acquiring GPS"
         case .recording: "Recording"
         case .paused: "Paused"
         case .finished: "Ride complete"
      }
   }

   var accuracyText: String? {
      guard let accuracy = state.horizontalAccuracy else { return nil }
      return RideFormatters.accuracy(accuracy, system: unitSystem)
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
