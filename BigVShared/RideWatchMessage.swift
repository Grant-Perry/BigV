//
//  RideWatchMessage.swift
//  BigVShared
//

import Foundation

/// Everything that can cross the wrist-to-phone link, as one closed set.
///
/// WatchConnectivity speaks in property-list dictionaries, which is a shape no
/// other layer of BigV should ever have to handle. This enum is the only place
/// that shape exists: the managers on both sides trade `RideWatchMessage`
/// values, and the codec below is pure, so the entire wire format is testable
/// without a paired Watch.
nonisolated enum RideWatchMessage: Sendable, Equatable {

   /// Phone to Watch: the current glance.
   case metrics(RideWatchMetricsSnapshot)

   /// Watch to phone: a live heart rate sample.
   case heartRate(RideWatchHeartRateReading)

   /// Watch to phone: the sensor session stopped, so drop the stale reading
   /// rather than leaving the last beat frozen on the dashboard.
   case heartRateEnded

   /// Watch to phone: a lifecycle request.
   case command(RideRemoteCommandRequest)

   /// Phone to Watch: what it did with that request.
   case commandReceipt(RideRemoteCommandReceipt)

   // MARK: - Wire Format

   private enum Key {
      static let kind = "kind"
      static let body = "body"
   }

   private enum Kind: String {
      case metrics
      case heartRate
      case heartRateEnded
      case command
      case commandReceipt
   }

   private var kind: Kind {
      switch self {
         case .metrics: .metrics
         case .heartRate: .heartRate
         case .heartRateEnded: .heartRateEnded
         case .command: .command
         case .commandReceipt: .commandReceipt
      }
   }

   private var body: [String: Any] {
      switch self {
         case .metrics(let snapshot): snapshot.body
         case .heartRate(let reading): reading.body
         case .heartRateEnded: [:]
         case .command(let request): request.body
         case .commandReceipt(let receipt): receipt.body
      }
   }

   /// The property-list dictionary to hand to `WCSession`.
   var payload: [String: Any] {
      [
         Key.kind: kind.rawValue,
         Key.body: body
      ]
   }

   /// Decodes a payload that arrived over the link. `nil` for anything this
   /// build does not recognise, so a newer counterpart can add message kinds
   /// without breaking an older one.
   init?(payload: [String: Any]) {
      guard let rawKind = payload[Key.kind] as? String,
            let kind = Kind(rawValue: rawKind)
      else { return nil }

      let body = payload[Key.body] as? [String: Any] ?? [:]

      switch kind {
         case .metrics:
            guard let snapshot = RideWatchMetricsSnapshot(body: body) else { return nil }
            self = .metrics(snapshot)

         case .heartRate:
            guard let reading = RideWatchHeartRateReading(body: body) else { return nil }
            self = .heartRate(reading)

         case .heartRateEnded:
            self = .heartRateEnded

         case .command:
            guard let request = RideRemoteCommandRequest(body: body) else { return nil }
            self = .command(request)

         case .commandReceipt:
            guard let receipt = RideRemoteCommandReceipt(body: body) else { return nil }
            self = .commandReceipt(receipt)
      }
   }
}
