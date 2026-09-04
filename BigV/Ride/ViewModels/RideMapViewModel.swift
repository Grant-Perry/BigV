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

   /// Everything, on both surfaces. A map the rider cannot drag is not a map,
   /// and the paging that used to depend on locking it now lives above the
   /// drawer on the dashboard and on a leading-edge swipe on the map page.
   var interactionModes: MapInteractionModes { .all }

   // MARK: - Drawer Camera

   /// The drawer is a 190-point strip, so MapKit's own follow altitude reads as
   /// a street atlas rather than the road ahead. Capping the camera distance is
   /// the only way to frame a `userLocation` camera closer.
   static let drawerCloseDistance: CLLocationDistance = 250

   /// Lifted the first time the rider pinches, so the cap only ever sets the
   /// default framing and never fights a gesture. Re-centring restores it.
   private(set) var isDrawerZoomFree = false

   // MARK: - Auto Re-Centre

   /// How long the rider keeps the camera after letting go of it.
   ///
   /// The camera coming back on its own is the whole point: MapKit drops a
   /// `userLocation` camera the instant a finger touches the map, so without
   /// this a single accidental drag leaves the rider watching a patch of road
   /// they have already left, with no way back but a deliberate tap.
   static let autoRecenterDelay: TimeInterval = 8

   /// A camera change this soon after a touch belongs to the rider — including
   /// the momentum that keeps arriving after the finger has gone.
   private static let touchGrace: TimeInterval = 1.5

   @ObservationIgnored private var autoRecenterTask: Task<Void, Never>?
   @ObservationIgnored private var lastRiderTouchAt: Date = .distantPast
   @ObservationIgnored private var lastFollowReassertAt: Date = .distantPast

   /// Set when the rider takes the camera on purpose — the explore button, a
   /// tapped turn, a framed route. A camera they asked for is theirs until they
   /// hand it back; only an incidental drag times out.
   @ObservationIgnored private var isExploringByChoice = false

   var drawerCameraBounds: MapCameraBounds {
      MapCameraBounds(
         minimumDistance: 40,
         maximumDistance: isDrawerZoomFree ? nil : Self.drawerCloseDistance
      )
   }

   /// MapKit stays in charge of the pinch itself; this only records that the
   /// rider now owns the drawer's zoom.
   func riderTookOverDrawerZoom() {
      riderBeganMovingCamera()

      guard !isDrawerZoomFree else { return }

      isDrawerZoomFree = true
      DebugPrint(mode: .navigation, "Drawer zoom released to rider")
   }

   // MARK: - Rider Camera Gestures

   /// A finger landed on the map. MapKit has already taken the camera off the
   /// rider by the time this runs, so this is bookkeeping catching up with what
   /// the map did, not a decision.
   func riderBeganMovingCamera() {
      lastRiderTouchAt = .now
      autoRecenterTask?.cancel()
      autoRecenterTask = nil

      guard isFollowingRider else { return }

      isFollowingRider = false
      DebugPrint(mode: .navigation, "Map released to rider")
   }

   /// The finger lifted. Start the countdown back to the rider.
   func riderFinishedMovingCamera() {
      lastRiderTouchAt = .now
      scheduleAutoRecenter()
   }

   private func scheduleAutoRecenter() {
      autoRecenterTask?.cancel()
      autoRecenterTask = nil

      guard !isExploringByChoice else { return }

      autoRecenterTask = Task { @MainActor [weak self] in
         try? await Task.sleep(for: .seconds(Self.autoRecenterDelay))
         guard !Task.isCancelled, let self, !self.isFollowingRider else { return }

         self.recenter()
      }
   }

   /// Puts the camera back on the rider when MapKit has quietly dropped a
   /// `userLocation` position while we still believe we are following.
   ///
   /// The one failure this exists for: an interaction the gesture hooks never
   /// saw — a momentum glide, a rotate that begins as a two-finger tap — leaves
   /// the map frozen over ground the rider has left, with every flag still
   /// saying it is following. Called from the camera-change callback, which is
   /// where such a drift becomes visible.
   func reassertFollowIfNeeded() {
      let now = Date.now

      // Called from a continuous camera callback, so it is rate limited: if
      // MapKit ever refuses a follow camera, this must correct once a second,
      // not fight it at frame rate.
      guard isFollowingRider,
            !cameraPosition.followsUserLocation,
            now.timeIntervalSince(lastRiderTouchAt) > Self.touchGrace,
            now.timeIntervalSince(lastFollowReassertAt) > 1
      else { return }

      lastFollowReassertAt = now
      cameraPosition = .followRider
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

      autoRecenterTask?.cancel()
      autoRecenterTask = nil
      isExploringByChoice = true

      guard let route = plannedRouteManager.activeRoute,
            let region = RideRouteBounds.region(for: route.coordinates)
      else { return }

      cameraPosition = .region(region)
      isFollowingRider = false

      DebugPrint(mode: .navigation, "Framed planned route")
   }

   // MARK: - Readouts

   /// Always a number. Sitting still is 0, not a dash — same rule as the cockpit.
   var speed: String {
      RideFormatters.speed(state.speed)
   }

   var speedUnit: String { RideUnitSystem.current.speedUnit }

   var distance: String { RideFormatters.distance(state.distance) }
   var distanceUnit: String { RideUnitSystem.current.distanceUnit }

   var heading: String {
      RideFormatters.cardinal(state.course) ?? RideFormatters.placeholder
   }

   /// `nil` while the course is unknown, so the view can hide the pill instead of
   /// showing a placeholder bearing.
   var headingDegrees: String? {
      RideFormatters.headingDegrees(state.course)
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
      autoRecenterTask?.cancel()
      autoRecenterTask = nil
      isExploringByChoice = false

      focusedManeuverID = nil
      focusedManeuverCoordinate = nil
      cameraPosition = .followRider
      isFollowingRider = true
      isDrawerZoomFree = false

      DebugPrint(mode: .navigation, "Map following rider")
   }

   /// Frames one planned step. Keeps the current 2D / 3D pitch.
   func focusManeuver(id: PlannedRouteManeuver.ID, coordinate: CLLocationCoordinate2D) {
      guard CLLocationCoordinate2DIsValid(coordinate) else { return }

      autoRecenterTask?.cancel()
      autoRecenterTask = nil
      isExploringByChoice = true

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
      autoRecenterTask?.cancel()
      autoRecenterTask = nil
      isExploringByChoice = true

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
