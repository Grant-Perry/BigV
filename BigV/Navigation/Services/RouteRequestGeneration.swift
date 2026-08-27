//
//  RouteRequestGeneration.swift
//  BigV
//

import Foundation

/// Orders overlapping search and routing work so a slow answer can never
/// overwrite a newer one.
///
/// Typing "main" then "main st" fires two searches; the network is free to answer
/// them in either order, and a delegate callback carries no clue which query it
/// belongs to. Every request takes a ticket, and only the newest ticket is
/// allowed to publish. Cancelling a request is the same act as issuing one: the
/// old ticket simply stops being current.
///
/// Pure value semantics, so the rule can be tested without a network.
struct RouteRequestGeneration: Sendable {

   // MARK: - State

   private var current: UInt64 = 0

   // MARK: - Issuing

   /// Opens a new generation, retiring every ticket issued before it.
   mutating func issue() -> UInt64 {
      current += 1
      return current
   }

   /// Retires every outstanding ticket without opening new work.
   mutating func retireAll() {
      current += 1
   }

   // MARK: - Checking

   /// Whether a result carrying `ticket` is still the newest work in flight.
   func isCurrent(_ ticket: UInt64) -> Bool {
      ticket == current
   }
}
