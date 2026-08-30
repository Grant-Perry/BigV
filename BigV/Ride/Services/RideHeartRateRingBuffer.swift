//
//  RideHeartRateRingBuffer.swift
//  BigV
//

import Foundation

/// In-memory recent heart-rate beats for the live chart only — never persisted.
///
/// Watch HR arrives faster than GPS samples are stored; the ring keeps the live
/// pulse line smooth without writing every beat to SwiftData.
@MainActor
final class RideHeartRateRingBuffer {

   struct Sample: Sendable {
      let timestamp: Date
      let beatsPerMinute: Double
   }

   private(set) var samples: [Sample] = []

   private let capacity: Int

   init(capacity: Int = 300) {
      self.capacity = capacity
   }

   func append(beatsPerMinute: Double, at timestamp: Date = .now) {
      guard RideWatchHeartRateReading.plausibleRange.contains(beatsPerMinute) else { return }

      samples.append(Sample(timestamp: timestamp, beatsPerMinute: beatsPerMinute))
      if samples.count > capacity {
         samples.removeFirst(samples.count - capacity)
      }
   }

   func clear() {
      samples.removeAll(keepingCapacity: true)
   }

   var count: Int { samples.count }

   func beats() -> [(timestamp: Date, beatsPerMinute: Double)] {
      samples.map { ($0.timestamp, $0.beatsPerMinute) }
   }
}
