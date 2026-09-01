//
//  RideViewModel.swift
//  BigV
//

import Foundation
import SwiftData
import SwiftUI

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
   let plusStore: BigVeloPlusStore?

   /// Opens the keep-BigVelo sheet after a refused START (phone or Watch).
   var isShowingAccessPaywall = false

   init(
      rideSessionManager: RideSessionManager = RideSessionManager(),
      rideRadarSettings: RideRadarSettings = RideRadarSettings(),
      rideUnitsSettings: RideUnitsSettings = RideUnitsSettings(),
      plusStore: BigVeloPlusStore? = nil
   ) {
      self.rideSessionManager = rideSessionManager
      self.rideRadarSettings = rideRadarSettings
      self.rideUnitsSettings = rideUnitsSettings
      self.plusStore = plusStore
   }

   var canBeginRide: Bool { plusStore?.canBeginRide ?? true }

   var showsAccessLock: Bool {
      !canBeginRide && (isIdle || isFinished)
   }

   var startDeniedPulse: Int { rideSessionManager.startDeniedPulse }

   func presentAccessPaywallIfLocked() {
      guard !canBeginRide else { return }
      isShowingAccessPaywall = true
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

   /// Always a number — a parked car still reads 0. Waiting on a fix used to
   /// leave a dash over a compass rose, which is not a speedometer.
   var speed: String {
      RideFormatters.speed(state.speed, system: unitSystem)
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

   /// Current altitude, or the placeholder until the engine trusts a fix.
   var altitude: String {
      guard let altitude = state.altitude else { return RideFormatters.placeholder }
      return RideFormatters.elevation(altitude, system: unitSystem)
   }

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

   /// The tape only earns screen while the link can still produce pips. A radar
   /// that is off, out of range, or done retrying leaves the cockpit clear; the
   /// status-row chip keeps carrying the OFF state, so nothing is hidden.
   var showsRadarTape: Bool { isRadarAvailable && radarConnection != .disconnected }

   /// The tape dims when the link is down or the ride is paused — present but
   /// visibly not live, matching the speed hero's treatment.
   var isRadarDimmed: Bool { !state.radar.isConnected || isPaused }

   var radarPlacement: RideRadarPlacement { rideRadarSettings.placement }

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

   func start() {
      presentAccessPaywallIfLocked()
      rideSessionManager.start()
   }
   func pause() { rideSessionManager.pause() }
   func resume() { rideSessionManager.resume() }
   func end() { rideSessionManager.end() }

   /// Cuts a lap by hand. The session ignores presses outside recording.
   func lap() { rideSessionManager.recordLap() }
   func reset() {
      clearSelectedMetric()
      clearLiveRadarTimeline()
      rideSessionManager.reset()
   }

   func startNewRide() {
      presentAccessPaywallIfLocked()
      guard canBeginRide else { return }
      clearSelectedMetric()
      clearLiveRadarTimeline()
      rideSessionManager.reset()
      rideSessionManager.start()
   }

   func flushPendingWork() { rideSessionManager.flushPendingWork() }

   // MARK: - Live Charts

   private(set) var selectedMetric: RideLiveMetric?
   private(set) var isLiveRadarTimelineVisible = false

   private(set) var liveHeartRateReport: RideHeartRateReport?
   private(set) var liveElevationReport: RideElevationReport?
   private(set) var liveSpeedReport: RideSpeedReport?
   private(set) var liveRadarReport: RideRadarReport?

   private var liveChartTask: Task<Void, Never>?
   private var lastLiveChartSampleCount = 0
   private var lastLiveHeartRateRingCount = 0
   private var lastLiveChartRefresh = Date.distantPast

   /// How often open live surfaces rebuild while visible.
   private let liveChartRefreshInterval: TimeInterval = 1.5

   private var isLiveChartSurfaceVisible: Bool {
      selectedMetric != nil || isLiveRadarTimelineVisible
   }

   /// Toggles a metric chart under the speed hero. Tap again to dismiss.
   func selectMetric(_ metric: RideLiveMetric) {
      if selectedMetric == metric {
         clearSelectedMetric()
         return
      }

      clearLiveRadarTimeline()
      selectedMetric = metric
      refreshLiveReports(force: true)
      startLiveChartLoopIfNeeded()
   }

   func clearSelectedMetric() {
      selectedMetric = nil
      liveHeartRateReport = nil
      liveElevationReport = nil
      liveSpeedReport = nil
      stopLiveChartLoopIfIdle()
   }

   /// Live traffic timeline under the speed hero while recording.
   func toggleLiveRadarTimeline() {
      if isLiveRadarTimelineVisible {
         clearLiveRadarTimeline()
         return
      }

      clearSelectedMetric()
      isLiveRadarTimelineVisible = true
      refreshLiveReports(force: true)
      startLiveChartLoopIfNeeded()
   }

   func clearLiveRadarTimeline() {
      isLiveRadarTimelineVisible = false
      liveRadarReport = nil
      stopLiveChartLoopIfIdle()
   }

   /// Drops live chart surfaces when the ride is no longer active.
   func syncLiveChartLifecycle() {
      guard state.phase == .recording || state.phase == .paused else {
         clearSelectedMetric()
         clearLiveRadarTimeline()
         return
      }
   }

   func liveMetricTint(for metric: RideLiveMetric) -> Color {
      switch metric {
         case .heartRate: RideDashboardTheme.pulse
         case .elevation: RideDashboardTheme.ice
         case .speed: RideDashboardTheme.ember
      }
   }

   private func startLiveChartLoopIfNeeded() {
      guard isLiveChartSurfaceVisible else { return }
      guard liveChartTask == nil else { return }

      liveChartTask = Task { @MainActor [weak self] in
         guard let self else { return }
         while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(liveChartRefreshInterval))
            guard !Task.isCancelled else { return }
            refreshLiveReportsIfDue()
         }
      }
   }

   private func stopLiveChartLoopIfIdle() {
      guard !isLiveChartSurfaceVisible else { return }

      liveChartTask?.cancel()
      liveChartTask = nil
      lastLiveChartSampleCount = 0
      lastLiveHeartRateRingCount = 0
      lastLiveChartRefresh = .distantPast
   }

   private func refreshLiveReportsIfDue() {
      let sampleCount = rideSessionManager.activeSampleCount
      let ringCount = rideSessionManager.heartRateRingSampleCount
      let elapsed = Date.now.timeIntervalSince(lastLiveChartRefresh)
      guard sampleCount != lastLiveChartSampleCount
            || ringCount != lastLiveHeartRateRingCount
            || elapsed >= liveChartRefreshInterval
      else { return }

      refreshLiveReports(force: false)
   }

   private func refreshLiveReports(force: Bool) {
      guard isLiveChartSurfaceVisible else { return }

      let sampleCount = rideSessionManager.activeSampleCount
      let ringCount = rideSessionManager.heartRateRingSampleCount
      if !force,
         sampleCount == lastLiveChartSampleCount,
         ringCount == lastLiveHeartRateRingCount,
         Date.now.timeIntervalSince(lastLiveChartRefresh) < liveChartRefreshInterval {
         return
      }

      lastLiveChartSampleCount = sampleCount
      lastLiveHeartRateRingCount = ringCount
      lastLiveChartRefresh = .now

      if selectedMetric != nil {
         refreshMetricReports()
      }

      if isLiveRadarTimelineVisible {
         refreshRadarReport()
      }
   }

   private func refreshMetricReports() {
      guard let chartData = rideSessionManager.activeRideChartSamples() else {
         liveHeartRateReport = nil
         liveElevationReport = nil
         liveSpeedReport = nil
         return
      }

      let samples = chartData.samples
      let system = unitSystem

      liveElevationReport = RideChartSeriesBuilder.elevationReport(
         samples: samples,
         elevationGain: state.elevationGain,
         elevationLoss: state.elevationLoss,
         system: system
      )

      liveSpeedReport = RideChartSeriesBuilder.speedReport(
         samples: samples,
         averageSpeed: state.averageSpeed,
         maximumSpeed: state.maximumSpeed,
         system: system
      )

      let ringBeats = rideSessionManager.heartRateRingBeats()
      let beats: [(timestamp: Date, beatsPerMinute: Double)]
      if ringBeats.count >= RideChartSeriesBuilder.minimumOwnHeartRateSamples {
         beats = ringBeats
      } else {
         beats = samples.compactMap { sample -> (Date, Double)? in
            guard let bpm = sample.heartRate, bpm > 0 else { return nil }
            return (sample.timestamp, bpm)
         }
      }

      if beats.count >= RideChartSeriesBuilder.minimumOwnHeartRateSamples {
         liveHeartRateReport = RideChartSeriesBuilder.heartRateReport(
            beats: beats,
            startDate: chartData.startDate,
            calories: nil,
            isFromAppleHealth: false
         )
      } else {
         liveHeartRateReport = nil
      }
   }

   private func refreshRadarReport() {
      guard let context = rideSessionManager.activeRideRadarContext() else {
         liveRadarReport = nil
         return
      }

      let elapsedMinutes = max(1, state.elapsedTime / 60)
      liveRadarReport = RideChartSeriesBuilder.radarReport(
         events: context.events,
         startDate: context.startDate,
         durationMinutes: elapsedMinutes,
         vehicleCount: context.vehicleCount,
         closestPassDistance: context.closestPassDistance,
         maximumClosingSpeed: context.maximumClosingSpeed,
         distanceMeters: context.distanceMeters,
         system: unitSystem
      )
   }
}
