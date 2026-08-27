//
//  RideRouteViewModel.swift
//  BigV
//

import Foundation
import SwiftData

/// Loads one saved ride's route and totals for a map-backed screen.
///
/// Reads from the store rather than from the live recorder, so a route survives
/// the app being relaunched and a ride reviewed weeks later looks identical to
/// the one just finished.
@Observable
@MainActor
final class RideRouteViewModel {

   // MARK: - State

   private(set) var route = RideRoute.empty
   private(set) var totals: RideTotals?
   private(set) var titleText = ""

   /// `true` once a load has resolved. Separates "the store has not answered yet"
   /// from "this ride genuinely has no route", so a screen waiting on a ride that
   /// is still being finalized never claims the route is missing.
   private(set) var isLoaded = false

   // MARK: - Dependencies

   /// Optional so previews can build a route screen with no store behind it,
   /// matching how `RideSessionManager` treats its own storage dependency.
   private let rideStorageManager: RideStorageManager?

   init(rideStorageManager: RideStorageManager? = nil) {
      self.rideStorageManager = rideStorageManager
   }

   // MARK: - Intent

   func load(_ identifier: PersistentIdentifier?) {
      guard let identifier,
            let ride = rideStorageManager?.ride(with: identifier)
      else {
         reset()
         isLoaded = true
         return
      }

      route = RideRoute(coordinates: RideRouteDownsampler.route(from: ride.samples))
      totals = RideTotals(ride: ride)
      titleText = ride.startDate.formatted(date: .abbreviated, time: .shortened)
      isLoaded = true

      DebugPrint(
         mode: .persistence,
         "Loaded route with \(route.coordinates.count) display points from \(ride.samples.count) samples"
      )
   }

   func clear() {
      reset()
      isLoaded = false
   }

   // MARK: - Reset

   private func reset() {
      route = .empty
      totals = nil
      titleText = ""
   }
}
