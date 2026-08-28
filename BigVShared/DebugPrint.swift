//
//  DebugPrint.swift
//  BigV
//

import Foundation
import Synchronization

// MARK: - Configuration

enum DebugConfig {

   /// Active debug areas. Keep this `.none` for production builds.
   ///
   /// Examples:
   /// - `.none` — silent (production)
   /// - `.ride` — the live ride engine
   /// - `[.locationFiltering, .telemetry]` — specific areas
   static let activeMode: DebugMode = .none
}

// MARK: - Debug Areas

struct DebugMode: OptionSet, Sendable {

   let rawValue: Int

   static let none                = DebugMode([])

   static let locationFiltering   = DebugMode(rawValue: 1 << 0)
   static let telemetry           = DebugMode(rawValue: 1 << 1)
   static let sessionLifecycle    = DebugMode(rawValue: 1 << 2)
   static let persistence         = DebugMode(rawValue: 1 << 3)
   static let healthKit           = DebugMode(rawValue: 1 << 4)
   static let sensors             = DebugMode(rawValue: 1 << 5)
   static let radar               = DebugMode(rawValue: 1 << 6)
   static let navigation          = DebugMode(rawValue: 1 << 7)

   // MARK: - Combinations

   static let ride: DebugMode = [.locationFiltering, .telemetry, .sessionLifecycle]
   static let all: DebugMode = [
      .locationFiltering, .telemetry, .sessionLifecycle, .persistence,
      .healthKit, .sensors, .radar, .navigation
   ]
}

// MARK: - Iteration Tracking

private let debugPrintIterations = Mutex<[String: Int]>([:])

// MARK: - Debug Print

/// Debug output filtered by area, with optional per-callsite iteration limiting.
///
/// - Parameters:
///   - mode: Area(s) this message belongs to.
///   - limit: Maximum times this callsite may print. `0` is unlimited.
///   - message: Message, only evaluated when it will actually print.
///
/// Examples:
/// ```swift
/// DebugPrint(mode: .telemetry, "Distance: \(distance)")
/// DebugPrint(mode: .locationFiltering, limit: 20, "Rejected: \(reason)")
/// ```
func DebugPrint(
   mode: DebugMode = .all,
   limit: Int = 0,
   file: String = #fileID,
   line: Int = #line,
   function: String = #function,
   _ message: @autoclosure () -> String
) {
   guard !DebugConfig.activeMode.intersection(mode).isEmpty else { return }

   let location = "\(file):\(line)"

   guard limit > 0 else {
      print("[\(location)] \(function) - \(message())")
      return
   }

   let iteration = debugPrintIterations.withLock { counters -> Int? in
      let count = counters[location, default: 0]
      guard count < limit else { return nil }
      counters[location] = count + 1
      return count + 1
   }

   guard let iteration else { return }
   print("[\(location)] \(function) [\(iteration)/\(limit)] - \(message())")
}
