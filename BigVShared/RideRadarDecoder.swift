//
//  RideRadarDecoder.swift
//  BigVShared
//

import Foundation

// MARK: - GATT Identity

/// The reverse-engineered Varia radar service, shared by the RTL family.
///
/// Strings, not `CBUUID`s, so this file stays framework-free and usable from
/// any target. Never subscribe the V2 stream (`6A4E3204`): it requires an LE
/// Secure Connections bond, and touching it early pins newer radars into modes
/// we cannot service.
nonisolated enum RideRadarGATT {

   static let serviceUUID = "6A4E3200-667B-11E3-949A-0800200C9A66"
   static let threatCharacteristicUUID = "6A4E3203-667B-11E3-949A-0800200C9A66"

   /// Garmin's member service, present in the advertisement alongside the
   /// radar service. Scan on both.
   static let garminMemberServiceUUID = "FE1F"

   static let batteryServiceUUID = "180F"
   static let batteryLevelCharacteristicUUID = "2A19"
   static let deviceInformationServiceUUID = "180A"
   static let modelNumberCharacteristicUUID = "2A24"
   static let firmwareRevisionCharacteristicUUID = "2A26"
}

// MARK: - Decoder

/// Decodes raw `6A4E3203` notifications into frames.
///
/// Pure byte math with no framework side effects, exactly like
/// `RideHeadingTapeGeometry`: callable from any isolation domain, testable
/// without a radio. Defensive on purpose — Garmin has changed this stream
/// between hardware generations, so an unexpected shape is classified, counted
/// by the caller, and never a crash.
nonisolated enum RideRadarDecoder {

   // MARK: - Wire Constants

   /// Payload length is `1 + 3N` for N tracked vehicles, at most 6 per notification.
   static let bytesPerTarget = 3
   static let maxTargetsPerNotification = 6

   /// The low nibble of byte 0 on every threat packet and heartbeat.
   private static let threatTypeNibble: UInt8 = 0x2

   /// Sector-amplitude diagnostic packets: 6 bytes, first byte `0x06`.
   private static let sectorAmplitudeMarker: UInt8 = 0x06
   private static let sectorAmplitudeLength = 6

   /// A track id below this has no presence bit and is not a vehicle.
   private static let presenceBit: UInt8 = 0x80

   /// Status marker seen in the id slot; skip the whole triplet.
   private static let statusMarkerID: UInt8 = 0xFD

   /// Distance sentinel for a far or uncertain target; skip the triplet.
   private static let distanceSentinel: UInt8 = 0xFF

   // MARK: - Classification

   enum Classification: Sendable, Equatable {

      /// Idle keepalive, one byte at roughly 7 Hz. No vehicles.
      case heartbeat(RideRadarFrame)

      /// One or more tracked vehicles.
      case threat(RideRadarFrame)

      /// Diagnostic packet some firmware emits; carries no targets.
      case sectorAmplitude

      /// A shape this decoder does not recognise. Count it, never crash on it.
      case unknown
   }

   /// Decodes one notification payload.
   static func classify(_ payload: [UInt8], receivedAt: Date = .now) -> Classification {
      guard let header = payload.first else { return .unknown }

      if payload.count == sectorAmplitudeLength, header == sectorAmplitudeMarker {
         return .sectorAmplitude
      }

      guard header & 0x0F == threatTypeNibble else { return .unknown }

      let sequence = header >> 4

      if payload.count == 1 {
         return .heartbeat(
            RideRadarFrame(sequence: sequence, targets: [], receivedAt: receivedAt)
         )
      }

      guard payload.count >= 1 + bytesPerTarget,
            (payload.count - 1) % bytesPerTarget == 0
      else { return .unknown }

      let targets = decodeTargets(from: payload)

      return .threat(
         RideRadarFrame(sequence: sequence, targets: targets, receivedAt: receivedAt)
      )
   }

   static func classify(_ payload: Data, receivedAt: Date = .now) -> Classification {
      classify([UInt8](payload), receivedAt: receivedAt)
   }

   // MARK: - Targets

   private static func decodeTargets(from payload: [UInt8]) -> [RideRadarTargetReading] {
      let tripletCount = (payload.count - 1) / bytesPerTarget
      var targets: [RideRadarTargetReading] = []
      targets.reserveCapacity(min(tripletCount, maxTargetsPerNotification))

      for index in 0..<tripletCount {
         let base = 1 + index * bytesPerTarget
         let vid = payload[base]
         let distance = payload[base + 1]
         let speedByte = payload[base + 2]

         // Sentinels, in the order the wire makes them cheap to test: no
         // presence bit (which also covers 0x00), the 0xFD status marker,
         // and the far/uncertain distance.
         guard vid >= presenceBit, vid != statusMarkerID, distance != distanceSentinel else {
            continue
         }

         targets.append(
            RideRadarTargetReading(
               trackID: vid & 0x7F,
               distanceMeters: Double(distance),
               rawSpeedByte: speedByte
            )
         )
      }

      return targets
   }
}
