//
//  RideSampleDraft.swift
//  BigV
//

import Foundation

/// A telemetry sample the engine accepted, ready to be persisted.
///
/// Keeps the session manager out of SwiftData and the storage manager out of
/// Core Location: one plain value crosses between them.
struct RideSampleDraft: Sendable, Equatable {

   let timestamp: Date

   // MARK: - Position

   let latitude: Double
   let longitude: Double
   let altitude: Double

   // MARK: - Derived Telemetry

   /// Smoothed speed in meters/second.
   let speed: Double

   /// Cumulative ride distance in meters at this sample.
   let distance: Double

   /// Grade percentage at this sample.
   let grade: Double

   /// Course over ground in degrees. Negative means unknown.
   let course: Double

   // MARK: - Sensors

   /// Beats per minute from the wrist at the moment this sample was accepted.
   /// `nil` whenever no Watch or strap was feeding one. Defaulted so callers
   /// without a body sensor build the draft they always did.
   var heartRate: Double? = nil
}
