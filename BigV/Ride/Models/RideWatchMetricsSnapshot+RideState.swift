//
//  RideWatchMetricsSnapshot+RideState.swift
//  BigV
//

import Foundation

extension RideWatchMetricsSnapshot {

   /// Projects the phone's ride state onto the wrist.
   ///
   /// One-way by design. The Watch reads this and renders it; nothing on the
   /// Watch reconstructs a `RideState`, because there is only ever one.
   ///
   /// Radar rides along only when the phone actually has a radar in play
   /// (`includesRadar`), so a radar-less rider's wrist never grows a
   /// disconnected pip for hardware they do not own.
   init(state: RideState, capturedAt: Date = .now, includesRadar: Bool = false) {
      self.init(
         phase: state.phase,
         speed: state.speed,
         distance: state.distance,
         elapsedTime: state.elapsedTime,
         hasGPSFix: state.hasGPSFix,
         isMoving: state.isMoving,
         capturedAt: capturedAt,
         locationIssue: state.locationIssue?.watchMessage,
         horizontalAccuracy: state.horizontalAccuracy,
         unitSystem: .current,
         radarConnected: includesRadar ? state.radar.isConnected : nil,
         radarTier: includesRadar ? state.radar.aggregateTier : nil,
         radarCount: includesRadar ? state.radar.tracks.count : nil,
         radarNearest: includesRadar ? state.radar.nearestDistanceMeters : nil,
         radarAlertPulse: includesRadar ? state.radar.alertPulse : nil,
         radarClearPulse: includesRadar ? state.radar.clearPulse : nil
      )
   }
}
