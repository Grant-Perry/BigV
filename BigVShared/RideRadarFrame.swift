//
//  RideRadarFrame.swift
//  BigVShared
//

import Foundation

/// One decoded radar notification: every vehicle the radar is tracking right now.
nonisolated struct RideRadarFrame: Sendable, Equatable {

   /// The packet's 4-bit wrapping sequence counter, `0...15`.
   let sequence: UInt8

   /// Up to six targets per notification; the radar tracks eight in total.
   let targets: [RideRadarTargetReading]

   let receivedAt: Date

   var isHeartbeat: Bool { targets.isEmpty }
}

/// A single vehicle as the radar reports it, unfiltered and uninterpreted.
///
/// The RTL515 gives distance only. Lateral offset and dimensions arrived with
/// the RearVue 820's bonded V2 stream and stay `nil` here; the tracker and the
/// tape are written against the optionals so an 820 path can fill them in later
/// without touching either.
nonisolated struct RideRadarTargetReading: Sendable, Equatable {

   /// Stable per-vehicle identifier, already stripped of the presence bit.
   let trackID: UInt8

   let distanceMeters: Double

   /// The wire's third byte, preserved raw. Its units are not reliably
   /// established across firmware generations, so interpretation lives in
   /// `RideRadarSpeedScale` and defaults to ignoring it — closing speed is
   /// derived from the distance derivative instead.
   let rawSpeedByte: UInt8

   // MARK: - Reserved for the 820 V2 stream

   var lateralOffsetMeters: Double? = nil
   var lengthMeters: Double? = nil
   var widthMeters: Double? = nil
}
