//
//  RouteGuidanceViewModel.swift
//  BigV
//

import CoreLocation
import Foundation

/// Presents live guidance to SwiftUI and forwards rider intent to the session.
///
/// Every string a guidance view shows is built here, so the banner and the
/// dashboard strip render the same figures without either of them formatting
/// anything.
@Observable
@MainActor
final class RouteGuidanceViewModel {

   // MARK: - Dependencies

   private let routeGuidanceManager: RouteGuidanceManager

   init(routeGuidanceManager: RouteGuidanceManager = RouteGuidanceManager()) {
      self.routeGuidanceManager = routeGuidanceManager
   }

   // MARK: - State

   private var phase: RouteGuidancePhase { routeGuidanceManager.phase }
   private var progress: RouteGuidanceProgress { routeGuidanceManager.progress }

   var isActive: Bool { phase.isActive }
   var isGuiding: Bool { phase == .guiding }
   var hasArrived: Bool { phase == .arrived }

   /// Whether the rider is being shown a turn rather than a problem.
   var showsInstruction: Bool {
      phase.showsInstructions && progress.upcomingInstruction != nil
   }

   var destinationName: String? { routeGuidanceManager.destinationName }

   /// Changes when a turn is close enough to be worth feeling. Views drive a
   /// haptic off this rather than the manager reaching for UIKit.
   var turnPulse: Int { routeGuidanceManager.turnPulse }

   // MARK: - Instruction

   var instruction: String? { progress.upcomingInstruction }

   /// A legal or safety notice attached to the upcoming step, shown verbatim.
   var notice: String? { progress.upcomingNotice }

   /// `nil` at the corner itself, where a "0 ft" readout is noise and the
   /// instruction is the whole message. The spoken cue drops the distance at the
   /// same point for the same reason.
   var turnDistance: String? {
      guard let distance = progress.distanceToUpcomingManeuver,
            distance >= Self.turnDistanceFloor
      else { return nil }

      return RouteGuidanceFormatters.turnDistance(distance)
   }

   private static let turnDistanceFloor: CLLocationDistance = 12

   var followingInstruction: String? {
      progress.followingInstruction.map { "Then \($0)" }
   }

   // MARK: - Destination Readouts

   var distanceRemaining: String {
      RouteGuidanceFormatters.distanceRemaining(progress.distanceRemaining)
   }

   var distanceRemainingUnit: String { RideFormatters.Unit.distance }

   var arrivalTime: String {
      RouteGuidanceFormatters.arrivalTime(progress.estimatedTimeRemaining)
   }

   var timeRemaining: String {
      RouteGuidanceFormatters.timeRemaining(progress.estimatedTimeRemaining)
   }

   /// `nil` while everything is normal, so views can show the turn instead.
   var summaryLine: String? {
      guard isActive else { return nil }
      return "\(distanceRemaining) \(distanceRemainingUnit) · \(arrivalTime)"
   }

   // MARK: - Exceptions

   /// The headline for anything that is not a turn: off route, rerouting,
   /// arrival. `nil` means guidance is behaving and the instruction should show.
   var statusTitle: String? {
      switch phase {
         case .inactive: nil
         case .guiding: progress.isAgainstRoute ? "WRONG WAY" : nil
         case .offRoute: "OFF ROUTE"
         case .rerouting: "REROUTING"
         case .rerouteUnavailable: "NO NEW ROUTE"
         case .arrived: "ARRIVED"
      }
   }

   var statusDetail: String? {
      switch phase {
         case .inactive: nil
         case .guiding: progress.isAgainstRoute ? "You are riding the route backwards" : nil
         case .offRoute: "Looking for a way back"
         case .rerouting: "Asking for a new route from here"
         case .rerouteUnavailable: "Head back to the route to resume"
         case .arrived: destinationName
      }
   }

   /// Whether the banner should read as a warning rather than as an instruction.
   var isAlerting: Bool {
      switch phase {
         case .offRoute, .rerouteUnavailable: true
         case .guiding: progress.isAgainstRoute
         case .inactive, .rerouting, .arrived: false
      }
   }

   var isWorking: Bool { phase == .rerouting }

   // MARK: - Turn List

   /// Provider steps for the active route. Never synthesized.
   var turns: [PlannedRouteManeuver] { routeGuidanceManager.maneuvers }

   var upcomingTurnID: PlannedRouteManeuver.ID? { progress.upcomingManeuverID }

   private(set) var selectedTurnID: PlannedRouteManeuver.ID?
   private(set) var isTurnListPresented = false

   var canPresentTurnList: Bool { isActive && !turns.isEmpty }

   func toggleTurnList() {
      guard canPresentTurnList else { return }
      isTurnListPresented.toggle()
   }

   func collapseTurnList() {
      isTurnListPresented = false
   }

   func selectTurn(_ turn: PlannedRouteManeuver) {
      selectedTurnID = turn.id
      isTurnListPresented = false
   }

   func distanceText(for turn: PlannedRouteManeuver) -> String? {
      if turn.id == upcomingTurnID, let remaining = progress.distanceToUpcomingManeuver {
         return remaining >= Self.turnDistanceFloor
            ? RouteGuidanceFormatters.turnDistance(remaining)
            : nil
      }

      guard turn.distance >= Self.turnDistanceFloor else { return nil }
      return RouteGuidanceFormatters.turnDistance(turn.distance)
   }

   // MARK: - Voice

   var isVoiceEnabled: Bool {
      get { routeGuidanceManager.isVoiceEnabled }
      set { routeGuidanceManager.isVoiceEnabled = newValue }
   }

   func toggleVoice() {
      routeGuidanceManager.isVoiceEnabled.toggle()
   }

   // MARK: - Intent

   func stopGuidance() {
      collapseTurnList()
      selectedTurnID = nil
      routeGuidanceManager.stopFollowing()
   }

   func dismissArrival() {
      collapseTurnList()
      selectedTurnID = nil
      routeGuidanceManager.dismissArrival()
   }
}
