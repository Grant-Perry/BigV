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

   /// How long a resolved fix is reused. A rider planning a route from the
   /// sofa has not moved in a minute, and re-probing per keystroke would be
   /// absurd. A rider planning *mid-ride* has — which is why the system's own
   /// latest fix is consulted first and wins whenever it is newer.
   private static let freshness: TimeInterval = 60

   /// Ceiling on waiting for a live fix. Past this, planning fails honestly
   /// instead of leaving the rider watching a spinner.
   private static let ceiling: Duration = .seconds(4)

   // MARK: - Private State

   private let locationManager = CLLocationManager()

   private var cachedCoordinate: CLLocationCoordinate2D?

   /// When the cached fix was *taken*, not when it was cached, so a system fix
   /// that is newer than it can be told apart.
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
   ///
   /// Newest fix wins. While a ride is recording the system holds a fix a few
   /// seconds old, and a route planned from a position a minute back would
   /// begin behind the rider — every turn then reads against the wrong start.
   func coordinate() async -> CLLocationCoordinate2D? {
      if let system = freshSystemFix { return remember(system) }
      if let fresh = freshCachedCoordinate { return fresh }

      guard isAuthorized else {
         requestAuthorizationIfNeeded()
         return nil
      }

      if let stale = locationManager.location, Self.isUsable(stale) {
         return remember(stale)
      }

      guard let live = await Self.liveFix() else {
         DebugPrint(mode: .navigation, "Location probe found no fix")
         return nil
      }

      return remember(live)
   }

   // MARK: - Cache

   /// The system's last fix, when it is both recent and newer than anything
   /// remembered here. Costs nothing: no session is started to read it.
   private var freshSystemFix: CLLocation? {
      guard isAuthorized,
            let location = locationManager.location,
            Self.isUsable(location),
            Date.now.timeIntervalSince(location.timestamp) < Self.freshness
      else { return nil }

      if let cachedAt, location.timestamp <= cachedAt { return nil }

      return location
   }

   private var freshCachedCoordinate: CLLocationCoordinate2D? {
      guard let cachedCoordinate,
            let cachedAt,
            Date.now.timeIntervalSince(cachedAt) < Self.freshness
      else { return nil }

      return cachedCoordinate
   }

   private func remember(_ location: CLLocation) -> CLLocationCoordinate2D {
      cachedCoordinate = location.coordinate
      cachedAt = location.timestamp
      return location.coordinate
   }

   private static func isUsable(_ location: CLLocation) -> Bool {
      RideRouteDownsampler.isUsable(location.coordinate)
   }

   // MARK: - Live Fix

   /// Races a single live update against the ceiling, so a device that never
   /// gets a fix cannot leave the caller suspended.
   private static func liveFix() async -> CLLocation? {
      await withTaskGroup(of: CLLocation?.self) { group in
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

   private static func firstFix() async -> CLLocation? {
      do {
         for try await update in CLLocationUpdate.liveUpdates(.default) {
            if Task.isCancelled { return nil }
            if update.authorizationDenied || update.authorizationDeniedGlobally { return nil }

            guard let location = update.location, isUsable(location) else { continue }

            return location
         }
      } catch {
         DebugPrint(mode: .navigation, "Location probe failed: \(error.localizedDescription)")
      }

      return nil
   }
}
