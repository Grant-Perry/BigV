//
//  ClimbProgressEngine.swift
//  BigV
//

import CoreLocation
import Foundation

/// Turns a route's elevation profile plus the rider's progress scalar into
/// what is left to climb.
///
/// Pure math with no framework side effects, deliberately mirroring
/// `RouteGuidanceEngine`: prepare it with a profile once, then every question
/// is answered from precomputed cumulative ascent by interpolation — never a
/// per-sample walk of the whole profile.
///
/// The progress scalar is `RouteGuidanceProgress.distanceAlongRoute`, which is
/// already provider-scaled into the same space the profile's distances live
/// in. Guidance math is not touched here; this engine only reads its output.
struct ClimbProgressEngine {

   // MARK: - Route

   private var profile: [RouteElevationSample] = []
   private var climbs: [PlannedClimb] = []

   /// `cumulativeAscent[i]` is every positive altitude delta from the route
   /// start to `profile[i]`, so ascent between any two distances is a
   /// subtraction of two interpolated reads.
   private var cumulativeAscent: [Double] = []

   private var totalAscent: Double = 0

   /// Whether a usable profile is loaded.
   var isReady: Bool { profile.count > 1 }

   // MARK: - Lifecycle

   mutating func prepare(profile: [RouteElevationSample], climbs: [PlannedClimb]) {
      reset()
      guard profile.count > 1 else { return }

      self.profile = profile
      self.climbs = climbs

      var running: Double = 0
      cumulativeAscent = [0]
      cumulativeAscent.reserveCapacity(profile.count)

      for (previous, sample) in zip(profile, profile.dropFirst()) {
         running += max(0, sample.altitude - previous.altitude)
         cumulativeAscent.append(running)
      }

      totalAscent = running
   }

   mutating func reset() {
      profile = []
      climbs = []
      cumulativeAscent = []
      totalAscent = 0
   }

   // MARK: - Progress

   /// The climb picture at `distanceAlongRoute` meters into the route.
   func progress(at distanceAlongRoute: CLLocationDistance) -> ClimbProgress {
      guard isReady else { return .none }

      let distance = min(max(0, distanceAlongRoute), routeLength)

      var progress = ClimbProgress()
      progress.hasRouteProfile = true
      progress.routeAscentRemaining = max(0, totalAscent - ascent(at: distance))
      progress.playheadDistance = distance
      progress.playheadAltitude = altitude(at: distance)

      if let active = climbs.first(where: { $0.contains(distance) }) {
         let toTop = max(0, active.endDistance - distance)
         let remaining = max(0, ascent(at: active.endDistance) - ascent(at: distance))

         progress.activeClimb = active
         progress.distanceToTop = toTop
         progress.climbAscentRemaining = remaining
         progress.averageRemainingGrade = toTop > 0 ? (remaining / toTop) * 100 : 0
      }

      if let next = climbs.first(where: { $0.startDistance > distance }) {
         progress.nextClimb = next
         progress.distanceToNextClimb = next.startDistance - distance
      }

      return progress
   }

   // MARK: - Interpolation

   private var routeLength: CLLocationDistance {
      profile.last?.distanceAlongRoute ?? 0
   }

   /// The profile altitude at an arbitrary distance, linearly interpolated.
   func altitude(at distance: CLLocationDistance) -> Double? {
      guard isReady else { return nil }
      let (index, fraction) = position(of: distance)
      guard index < profile.count - 1 else { return profile.last?.altitude }

      let lower = profile[index].altitude
      let upper = profile[index + 1].altitude
      return lower + (upper - lower) * fraction
   }

   /// Cumulative ascent at an arbitrary distance, linearly interpolated.
   ///
   /// Interpolating the cumulative curve rather than snapping to a sample is
   /// what keeps the remaining figure moving smoothly as the rider grinds
   /// through one 75 m profile segment.
   private func ascent(at distance: CLLocationDistance) -> Double {
      let (index, fraction) = position(of: distance)
      guard index < cumulativeAscent.count - 1 else { return totalAscent }

      let lower = cumulativeAscent[index]
      let upper = cumulativeAscent[index + 1]
      return lower + (upper - lower) * fraction
   }

   /// The segment a distance falls in and how far through it, by binary search.
   private func position(of distance: CLLocationDistance) -> (index: Int, fraction: Double) {
      var low = 0
      var high = profile.count - 1

      while low < high {
         let mid = (low + high + 1) / 2
         if profile[mid].distanceAlongRoute <= distance {
            low = mid
         } else {
            high = mid - 1
         }
      }

      guard low < profile.count - 1 else { return (low, 0) }

      let segmentStart = profile[low].distanceAlongRoute
      let segmentLength = profile[low + 1].distanceAlongRoute - segmentStart
      guard segmentLength > 0 else { return (low, 0) }

      return (low, min(1, max(0, (distance - segmentStart) / segmentLength)))
   }
}
