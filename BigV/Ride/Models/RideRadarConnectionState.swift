//
//  RideRadarConnectionState.swift
//  BigV
//

import Foundation

/// Where the radar link stands, from the rider's point of view.
enum RideRadarConnectionState: String, Sendable, Equatable {

   /// No radar configured, or the link is deliberately down.
   case disconnected

   /// Looking for the remembered radar, or discovering one to pair.
   case scanning

   case connecting

   /// Notifications are flowing.
   case connected

   var isConnected: Bool { self == .connected }
}
