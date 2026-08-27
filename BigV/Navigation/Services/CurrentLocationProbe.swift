//
//  CurrentLocationProbe.swift
//  BigV
//

import CoreLocation
import Foundation

/// Answers "where is the rider right now" once, on demand.
///
/// Route planning needs an origin and search needs somewhere to bias toward, and
/// both are asked for while the app is idle — before any ride has started, so
/// before `RideLocationManager` has a stream running. Deliberately separate from
/// that manager: nothing here may touch the ride's authorization or its
/// background activity session.
///
/// Tries the system's cached fix first, which costs nothing, and only starts a
/// short live session when there is no cache to read.
@MainActor
final class CurrentLocationProbe {

   // MARK: - Tuning

   /// How long a resolved fix is reused. A rider planning a route has not moved
   /// far in a minute, and re-probing per keystroke would be absurd.
   private static let freshness: TimeInterval = 60

   /// Ceiling on waiting for a live fix. Past this, planning fails honestly
   /// instead of leaving the rider watching a spinner.
   private static let ceiling: Duration = .seconds(4)

   // MARK: - Private State

   private let locationManager = CLLocationManager()

   private var cachedCoordinate: CLLocationCoordinate2D?
   private var cachedAt: Date?

   // MARK: - Authorization

   var isAuthorized: Bool {
      switch locationManager.authorizationStatus {
         case .authorizedAlways, .authorizedWhenInUse: true
         default: false
      }
   }

   func requestAuthorizationIfNeeded() {
      guard locationManager.authorizationStatus == .notDetermined else { return }
      locationManager.requestWhenInUseAuthorization()
   }

   // MARK: - Probing

   /// The rider's coordinate, or `nil` when it cannot be established.
   func coordinate() async -> CLLocationCoordinate2D? {
      if let fresh = freshCachedCoordinate { return fresh }

      guard isAuthorized else {
         requestAuthorizationIfNeeded()
         return nil
      }

      if let cached = locationManager.location?.coordinate,
         RideRouteDownsampler.isUsable(cached) {
         return remember(cached)
      }

      guard let live = await Self.liveCoordinate() else {
         DebugPrint(mode: .navigation, "Location probe found no fix")
         return nil
      }

      return remember(live)
   }

   // MARK: - Cache

   private var freshCachedCoordinate: CLLocationCoordinate2D? {
      guard let cachedCoordinate,
            let cachedAt,
            Date.now.timeIntervalSince(cachedAt) < Self.freshness
      else { return nil }

      return cachedCoordinate
   }

   private func remember(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
      cachedCoordinate = coordinate
      cachedAt = .now
      return coordinate
   }

   // MARK: - Live Fix

   /// Races a single live update against the ceiling, so a device that never
   /// gets a fix cannot leave the caller suspended.
   private static func liveCoordinate() async -> CLLocationCoordinate2D? {
      await withTaskGroup(of: CLLocationCoordinate2D?.self) { group in
         group.addTask { await firstFix() }
         group.addTask {
            try? await Task.sleep(for: ceiling)
            return nil
         }

         let first = await group.next() ?? nil
         group.cancelAll()

         return first
      }
   }

   private static func firstFix() async -> CLLocationCoordinate2D? {
      do {
         for try await update in CLLocationUpdate.liveUpdates(.default) {
            if Task.isCancelled { return nil }
            if update.authorizationDenied || update.authorizationDeniedGlobally { return nil }

            guard let coordinate = update.location?.coordinate,
                  RideRouteDownsampler.isUsable(coordinate)
            else { continue }

            return coordinate
         }
      } catch {
         DebugPrint(mode: .navigation, "Location probe failed: \(error.localizedDescription)")
      }

      return nil
   }
}
