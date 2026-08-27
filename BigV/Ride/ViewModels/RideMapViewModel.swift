//
//  RideMapViewModel.swift
//  BigV
//

import CoreLocation
import Foundation
import MapKit
import SwiftUI

/// Presents the live map: the breadcrumb, the overlaid numbers and the camera.
///
/// The camera lives here rather than in the view so the follow-versus-explore
/// decision is coordination, not something a view body works out.
@Observable
@MainActor
final class RideMapViewModel {

   // MARK: - Camera

   /// Follows the rider and rotates to heading by default, which is what a bike
   /// computer on a handlebar should do without being asked.
   var cameraPosition: MapCameraPosition = .followRider

   private(set) var isFollowingRider = true

   /// Session-scoped. Recenter keeps whatever the rider last chose.
   private(set) var isPitched = false
   private(set) var isSatellite = false

   /// Cheap highlight after a rider jumps to a turn. Cleared on recenter.
   private(set) var focusedManeuverID: PlannedRouteManeuver.ID?
   private(set) var focusedManeuverCoordinate: CLLocationCoordinate2D?

   /// While following, single-finger drags are left alone so the page swipe still
   /// reaches the pager: a full-bleed pannable map swallows horizontal drags and
   /// strands the rider on this page. Pinch and rotate are multi-touch, so they
   /// never collide with paging and stay available throughout.
   var interactionModes: MapInteractionModes {
      isFollowingRider ? [.zoom, .rotate] : .all
   }

   /// The camera to freeze on when the rider takes over. Deliberately untracked:
   /// it is written on every camera change so handing over is always possible,
   /// and storing an untracked struct must never invalidate a view.
   @ObservationIgnored private var lastCamera: MapCamera?

   // MARK: - Dependencies

   private let rideSessionManager: RideSessionManager
   private let rideRouteRecorder: RideRouteRecorder
   private let plannedRouteManager: PlannedRouteManager

   init(
      rideSessionManager: RideSessionManager = RideSessionManager(),
      rideRouteRecorder: RideRouteRecorder = RideRouteRecorder(),
      plannedRouteManager: PlannedRouteManager = PlannedRouteManager()
   ) {
      self.rideSessionManager = rideSessionManager
      self.rideRouteRecorder = rideRouteRecorder
      self.plannedRouteManager = plannedRouteManager
   }

   // MARK: - State

   private var state: RideState { rideSessionManager.state }

   var isIdle: Bool { state.phase == .idle }

   var routeCoordinates: [CLLocationCoordinate2D] { rideRouteRecorder.coordinates }
   var hasRoute: Bool { rideRouteRecorder.hasRoute }

   // MARK: - Planned Route

   var plannedRouteCoordinates: [CLLocationCoordinate2D] {
      plannedRouteManager.activeRoute?.coordinates ?? []
   }

   var hasPlannedRoute: Bool { plannedRouteManager.hasActiveRoute }

   /// Changes when a different route is committed, and only then. The view uses
   /// it to know when framing the whole route is worth taking the camera for.
   var plannedRouteID: PlannedRoute.ID? { plannedRouteManager.activeRoute?.id }

   var destinationCoordinate: CLLocationCoordinate2D? {
      plannedRouteManager.destination?.coordinate
   }

   var destinationName: String? { plannedRouteManager.destination?.name }

   func clearPlannedRoute() {
      plannedRouteManager.clear()
      focusedManeuverID = nil
      focusedManeuverCoordinate = nil
      recenter()
   }

   /// Frames the whole planned route once, releasing the follow camera. A rider
   /// who has just committed to a route wants to see all of it; the re-center
   /// control hands the camera straight back.
   ///
   /// Only while idle. A reroute activates a replacement route mid-ride, and
   /// zooming out to admire it would take the camera off a rider who is at that
   /// moment lost.
   func framePlannedRoute() {
      guard isIdle else { return }

      guard let route = plannedRouteManager.activeRoute,
            let region = RideRouteBounds.region(for: route.coordinates)
      else { return }

      cameraPosition = .region(region)
      isFollowingRider = false

      DebugPrint(mode: .navigation, "Framed planned route")
   }

   // MARK: - Readouts

   var speed: String {
      state.hasGPSFix ? RideFormatters.speed(state.speed) : RideFormatters.placeholder
   }

   var speedUnit: String { RideFormatters.Unit.speed }

   var distance: String { RideFormatters.distance(state.distance) }
   var distanceUnit: String { RideFormatters.Unit.distance }

   var heading: String {
      RideFormatters.cardinal(state.course) ?? RideFormatters.placeholder
   }

   /// `nil` while the course is unknown, so the view can hide the pill instead of
   /// showing a placeholder bearing.
   var headingDegrees: String? {
      guard state.course >= 0 else { return nil }
      return "\(Int(state.course.rounded()))°"
   }

   // MARK: - Map Presentation

   var mapStyle: MapStyle {
      let elevation: MapStyle.Elevation = isPitched ? .realistic : .flat

      if isSatellite {
         return .hybrid(
            elevation: elevation,
            pointsOfInterest: .excludingAll
         )
      }

      return .standard(
         elevation: elevation,
         emphasis: .muted,
         pointsOfInterest: .excludingAll,
         showsTraffic: false
      )
   }

   func togglePitch() {
      isPitched.toggle()
      applyPitchToFrozenCamera()
      DebugPrint(mode: .navigation, isPitched ? "Map 3D" : "Map 2D")
   }

   func toggleSatellite() {
      isSatellite.toggle()
      DebugPrint(mode: .navigation, isSatellite ? "Map satellite" : "Map road")
   }

   // MARK: - Intent

   func toggleCameraMode() {
      if isFollowingRider {
         releaseCamera()
      } else {
         recenter()
      }
   }

   func recenter() {
      focusedManeuverID = nil
      focusedManeuverCoordinate = nil
      cameraPosition = .followRider
      isFollowingRider = true

      DebugPrint(mode: .navigation, "Map following rider")
   }

   /// Frames one planned step. Keeps the current 2D / 3D pitch.
   func focusManeuver(id: PlannedRouteManeuver.ID, coordinate: CLLocationCoordinate2D) {
      guard CLLocationCoordinate2DIsValid(coordinate) else { return }

      focusedManeuverID = id
      focusedManeuverCoordinate = coordinate

      cameraPosition = .camera(
         MapCamera(
            centerCoordinate: coordinate,
            distance: lastCamera?.distance ?? 420,
            heading: lastCamera?.heading ?? 0,
            pitch: isPitched ? 52 : 0
         )
      )
      isFollowingRider = false

      DebugPrint(mode: .navigation, "Map focused on turn \(id)")
   }

   func rememberCamera(_ camera: MapCamera) {
      lastCamera = camera
   }

   // MARK: - Camera Release

   private func releaseCamera() {
      guard let lastCamera else { return }

      cameraPosition = .camera(pitched(lastCamera))
      isFollowingRider = false

      DebugPrint(mode: .navigation, "Map released for free pan")
   }

   private func applyPitchToFrozenCamera() {
      guard !isFollowingRider, let lastCamera else { return }
      cameraPosition = .camera(pitched(lastCamera))
   }

   private func pitched(_ camera: MapCamera) -> MapCamera {
      MapCamera(
         centerCoordinate: camera.centerCoordinate,
         distance: camera.distance,
         heading: camera.heading,
         pitch: isPitched ? 52 : 0
      )
   }
}

// MARK: - Camera Presets

private extension MapCameraPosition {

   /// Falls back to the whole route while the first fix is still being acquired,
   /// so the map is never a blank grid.
   static let followRider = MapCameraPosition.userLocation(
      followsHeading: true,
      fallback: .automatic
   )
}
