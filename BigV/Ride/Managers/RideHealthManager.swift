//
//  RideHealthManager.swift
//  BigV
//

import CoreLocation
import Foundation
import HealthKit

/// Projects a finished ride into Apple Health as a cycling workout.
///
/// The write happens once, at the end, from rows BigV already persisted. A live
/// `HKWorkoutSession` would add a second stateful recorder on the hot path with
/// nothing to gain: BigV already owns the truth, and iPhone-only cycling has no
/// need for session mirroring. Failure here is always survivable.
@MainActor
final class RideHealthManager {

   // MARK: - Outcome

   enum Outcome: Sendable, Equatable {
      case saved(UUID)
      case denied
      case unavailable
      case failed(String)
   }

   // MARK: - Private Properties

   private let healthStore = HKHealthStore()

   /// Route locations must carry believable accuracy or HealthKit refuses them.
   /// These mirror the gates every stored sample already passed.
   private static let routeHorizontalAccuracy = RideTelemetryEngine.Configuration.default.maxHorizontalAccuracy
   private static let routeVerticalAccuracy = RideTelemetryEngine.Configuration.default.maxVerticalAccuracy

   private var shareTypes: Set<HKSampleType> {
      [
         HKObjectType.workoutType(),
         HKSeriesType.workoutRoute(),
         HKQuantityType(.distanceCycling),
         HKQuantityType(.activeEnergyBurned)
      ]
   }

   // MARK: - Authorization

   /// Asks once, in context, while the rider is waiting for a GPS fix.
   func requestAuthorizationIfNeeded() async {
      guard HKHealthStore.isHealthDataAvailable() else { return }
      guard healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .notDetermined else { return }

      do {
         try await healthStore.requestAuthorization(toShare: shareTypes, read: [])
      } catch {
         DebugPrint(mode: .healthKit, "Authorization request failed: \(error.localizedDescription)")
      }
   }

   // MARK: - Export

   func export(_ ride: Ride) async -> Outcome {
      guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }

      let start = ride.startDate
      let end = ride.endDate ?? start.addingTimeInterval(ride.duration)

      guard end > start else { return .failed("Ride has no measurable interval") }

      let distance = ride.distance
      let activeEnergy = ride.activeEnergy
      let route = Self.routeLocations(from: ride.samples, within: start...end)

      await requestAuthorizationIfNeeded()

      guard healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else {
         DebugPrint(mode: .healthKit, "Workout sharing not authorized; ride stays local only")
         return .denied
      }

      do {
         let workout = try await writeWorkout(
            from: start,
            to: end,
            distance: distance,
            activeEnergy: activeEnergy
         )

         await insertRoute(route, for: workout)

         DebugPrint(mode: .healthKit, "Workout saved \(workout.uuid) with \(route.count) route points")
         return .saved(workout.uuid)
      } catch {
         DebugPrint(mode: .healthKit, "Workout write failed: \(error.localizedDescription)")
         return .failed(error.localizedDescription)
      }
   }

   // MARK: - Workout

   private func writeWorkout(
      from start: Date,
      to end: Date,
      distance: Double,
      activeEnergy: Double?
   ) async throws -> HKWorkout {
      let configuration = HKWorkoutConfiguration()
      configuration.activityType = .cycling
      configuration.locationType = .outdoor

      let workoutBuilder = HKWorkoutBuilder(
         healthStore: healthStore,
         configuration: configuration,
         device: .local()
      )

      try await workoutBuilder.beginCollection(at: start)

      let samples = Self.quantitySamples(
         distance: distance,
         activeEnergy: activeEnergy,
         from: start,
         to: end
      )
      if !samples.isEmpty {
         try await Self.add(samples, to: workoutBuilder)
      }

      try await workoutBuilder.endCollection(at: end)

      guard let workout = try await workoutBuilder.finishWorkout() else {
         throw RideHealthExportError.workoutNotReturned
      }

      return workout
   }

   /// `HKWorkoutBuilder.add(_:)` is overloaded, so Swift never surfaces its
   /// generated async form. Bridged rather than reached for on the caller side.
   private static func add(_ samples: [HKSample], to workoutBuilder: HKWorkoutBuilder) async throws {
      try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
         workoutBuilder.add(samples) { _, error in
            if let error {
               continuation.resume(throwing: error)
            } else {
               continuation.resume()
            }
         }
      }
   }

   private static func quantitySamples(
      distance: Double,
      activeEnergy: Double?,
      from start: Date,
      to end: Date
   ) -> [HKSample] {
      var samples: [HKSample] = []

      if distance > 0 {
         samples.append(
            HKQuantitySample(
               type: HKQuantityType(.distanceCycling),
               quantity: HKQuantity(unit: .meter(), doubleValue: distance),
               start: start,
               end: end
            )
         )
      }

      if let activeEnergy, activeEnergy > 0 {
         samples.append(
            HKQuantitySample(
               type: HKQuantityType(.activeEnergyBurned),
               quantity: HKQuantity(unit: .kilocalorie(), doubleValue: activeEnergy),
               start: start,
               end: end
            )
         )
      }

      return samples
   }

   // MARK: - Route

   /// A missing route is a lesser failure than a missing workout, so this never
   /// invalidates a workout that already landed.
   private func insertRoute(_ locations: [CLLocation], for workout: HKWorkout) async {
      guard locations.count > 1 else { return }

      let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())

      do {
         try await routeBuilder.insertRouteData(locations)
         _ = try await routeBuilder.finishRoute(with: workout, metadata: nil)
      } catch {
         DebugPrint(mode: .healthKit, "Route write failed: \(error.localizedDescription)")
      }
   }

   /// Built only from engine-accepted samples, never from raw Core Location.
   private static func routeLocations(
      from samples: [RideSample],
      within interval: ClosedRange<Date>
   ) -> [CLLocation] {
      samples
         .filter { interval.contains($0.timestamp) }
         .sorted { $0.timestamp < $1.timestamp }
         .map { sample in
            CLLocation(
               coordinate: CLLocationCoordinate2D(
                  latitude: sample.latitude,
                  longitude: sample.longitude
               ),
               altitude: sample.altitude,
               horizontalAccuracy: routeHorizontalAccuracy,
               verticalAccuracy: routeVerticalAccuracy,
               course: sample.course,
               speed: sample.speed,
               timestamp: sample.timestamp
            )
         }
   }
}

// MARK: - Errors

enum RideHealthExportError: Error, LocalizedError {

   case workoutNotReturned

   var errorDescription: String? {
      switch self {
         case .workoutNotReturned: "HealthKit finished without returning a workout."
      }
   }
}
