//
//  RideRadarLinkEvent.swift
//  BigV
//

import Foundation

/// Everything a radar source can tell the session.
///
/// This is the seam: `RideRadarManager` (Core Bluetooth) and
/// `RideRadarSimulator` (scripted scenarios) both emit it on an
/// `AsyncStream`, so the session, tracker and views cannot tell hardware
/// from script — which is also how App Review gets a working demo without
/// a radar on the desk.
enum RideRadarLinkEvent: Sendable, Equatable {

   case frame(RideRadarFrame)
   case connection(RideRadarConnectionState)

   /// Battery percent, `0...100`.
   case battery(Int)

   case issue(RideRadarIssue)
}
