//
//  RideRadarSpeedScale.swift
//  BigVShared
//

import Foundation

/// How to read the wire's third byte, if at all.
///
/// The evidence disagrees: harbour-tacho and pycycling read km/h,
/// MyBikeTraffic reads m/s, the original reverse-engineer claimed a packed
/// field, and on the RearVue 820 the byte only ever carries 0 or 1. Closing
/// speed is therefore derived from the distance derivative, and this scale
/// stays `.ignored` until captures from the actual RTL515 prove otherwise.
nonisolated enum RideRadarSpeedScale: String, Sendable, Equatable, CaseIterable {

   case ignored
   case metersPerSecond
   case kilometersPerHour

   /// ANT+ cycling-radar quantisation: 3.04 m/s per LSB.
   case antQuantized

   static let `default`: RideRadarSpeedScale = .ignored

   /// The byte as m/s under this interpretation, or `nil` when ignored.
   func metersPerSecond(fromRawByte byte: UInt8) -> Double? {
      switch self {
         case .ignored: nil
         case .metersPerSecond: Double(byte)
         case .kilometersPerHour: Double(byte) / 3.6
         case .antQuantized: Double(byte) * 3.04
      }
   }
}
