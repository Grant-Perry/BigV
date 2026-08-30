//
//  RideLiveMetric.swift
//  BigV
//

import Foundation

/// A chartable metric the rider can pin to the cockpit hero while recording.
enum RideLiveMetric: String, Sendable, Equatable, CaseIterable, Identifiable {

   case heartRate
   case elevation
   case speed

   var id: String { rawValue }

   var title: String {
      switch self {
         case .heartRate: "HEART RATE"
         case .elevation: "ELEVATION"
         case .speed: "SPEED"
      }
   }

   var iconName: String {
      switch self {
         case .heartRate: "heart.fill"
         case .elevation: "mountain.2.fill"
         case .speed: "gauge.with.needle.fill"
      }
   }

   /// Placeholder when the series is not ready yet.
   var waitingMessage: String {
      switch self {
         case .heartRate: "Waiting for pulse…"
         case .elevation: "Waiting for GPS…"
         case .speed: "Waiting for GPS…"
      }
   }
}
