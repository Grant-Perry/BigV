//
//  RideWatchWorkoutManager.swift
//  BigV Watch App
//

import Foundation
import HealthKit

/// Runs an `HKWorkoutSession` on the Watch purely as a **sensor**.
///
/// ## Why a session at all
///
/// An active `HKWorkoutSession` is the only thing on watchOS that raises the
/// optical sensor to workout sampling rates and keeps this app alive with the
/// wrist down. Without one, a heart rate query returns almost nothing — there is
/// no alternative API, extended runtime sessions included.
///
/// ## Why it never saves
///
/// The iPhone is the system of record. `RideHealthManager` writes exactly one
/// `HKWorkout` at the end of the ride, from rows BigV already persisted. Two
/// savers would mean two workouts in Health for one ride — the duplicate-workout
/// class of bug BigMetric shipped.
///
/// So this manager takes the sensor half of the session and refuses the recording
/// half. It never touches `associatedWorkoutBuilder`, never calls
/// `beginCollection`, and therefore has nothing to `finishWorkout` or
/// `discardWorkout`. A workout object cannot appear from this target, because the
/// object that would create one is never brought into existence.
///
/// Activity rings are unaffected by that choice. watchOS credits Move and
/// Exercise for the duration of an active session regardless of who saves the
/// workout — it is not even possible to opt out — so the rider gets full ring
/// credit from the Watch while Health gets a single workout from the phone.
///
/// Authorization to *share* workouts is still requested, because `HKWorkoutSession`
/// refuses to start without it. That permission is the price of the sensor, not a
/// statement of intent.
///
/// ## Lingering sessions
///
/// watchOS preserves an active session across a crash or a force-quit and
/// relaunches the app for it. `endOrphanedSession()` sweeps that up at launch,
/// before anything else starts. Because this session never saved anything, the
/// sweep is unambiguous: end it. There is no rider data to weigh against a clean
/// slate — the phone has the ride.
@Observable
@MainActor
final class RideWatchWorkoutManager {

   // MARK: - Published State

   private(set) var isSensing = false

   /// Set when the sensor could not run. The ride is unaffected: the phone owns
   /// recording, so losing heart rate costs a metric, never a ride.
   private(set) var failure: String?

   // MARK: - Private Properties

   private let healthStore = HKHealthStore()

   private var session: HKWorkoutSession?
   private var relay: RideWatchWorkoutRelay?
   private var relayTask: Task<Void, Never>?

   private var heartRateTask: Task<Void, Never>?
   private var heartRateContinuation: AsyncStream<RideWatchHeartRateReading>.Continuation?

   /// Starting a session requires sharing workouts; reading heart rate requires
   /// reading it. Nothing here is ever written.
   private var shareTypes: Set<HKSampleType> { [HKObjectType.workoutType()] }
   private var readTypes: Set<HKObjectType> { [HKQuantityType(.heartRate)] }

   // MARK: - Authorization

   func requestAuthorization() async {
      guard HKHealthStore.isHealthDataAvailable() else {
         failure = "Health data unavailable"
         return
      }

      do {
         try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
      } catch {
         DebugPrint(mode: .healthKit, "Watch authorization request failed: \(error.localizedDescription)")
      }
   }

   // MARK: - Recovery

   /// Ends a session that outlived the app. Must run before the first
   /// `startSensing()`, or it could recover — and then end — the session we just
   /// opened ourselves.
   func endOrphanedSession() async {
      guard HKHealthStore.isHealthDataAvailable(), session == nil else { return }

      do {
         guard let recovered = try await healthStore.recoverActiveWorkoutSession() else { return }

         recovered.end()
         DebugPrint(mode: .healthKit, "Ended an orphaned workout session from a previous launch")
      } catch {
         DebugPrint(mode: .healthKit, "Workout session recovery failed: \(error.localizedDescription)")
      }
   }

   // MARK: - Sensing

   /// Opens the sensor session and streams heart rate for as long as it runs.
   func startSensing() -> AsyncStream<RideWatchHeartRateReading> {
      stopSensing()

      let (stream, continuation) = AsyncStream<RideWatchHeartRateReading>.makeStream(
         bufferingPolicy: .bufferingNewest(8)
      )
      heartRateContinuation = continuation

      guard HKHealthStore.isHealthDataAvailable() else {
         failure = "Health data unavailable"
         continuation.finish()
         return stream
      }

      let configuration = HKWorkoutConfiguration()
      configuration.activityType = .cycling
      configuration.locationType = .outdoor

      do {
         let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
         let startDate = Date.now

         startRelay(for: session)
         session.startActivity(with: startDate)

         self.session = session
         isSensing = true
         failure = nil

         startHeartRateStream(from: startDate, into: continuation)

         DebugPrint(mode: .healthKit, "Sensor session started (no workout will be saved)")
      } catch {
         failure = error.localizedDescription
         continuation.finish()

         DebugPrint(mode: .healthKit, "Sensor session failed to start: \(error.localizedDescription)")
      }

      return stream
   }

   /// Tears the session down unconditionally.
   ///
   /// A bare `end()` is the whole teardown. The documented sequence —
   /// `endCollection` then `finishWorkout` — exists to save a workout, and there
   /// is no builder here to save one from.
   func stopSensing() {
      heartRateTask?.cancel()
      heartRateTask = nil

      heartRateContinuation?.finish()
      heartRateContinuation = nil

      relayTask?.cancel()
      relayTask = nil

      relay?.finish()
      relay = nil

      guard let session else {
         isSensing = false
         return
      }

      session.end()
      self.session = nil
      isSensing = false

      DebugPrint(mode: .healthKit, "Sensor session ended")
   }

   // MARK: - Session Events

   private func startRelay(for session: HKWorkoutSession) {
      let (relayStream, relayContinuation) = AsyncStream<RideWatchSensorEvent>.makeStream(
         bufferingPolicy: .bufferingNewest(8)
      )

      let relay = RideWatchWorkoutRelay(continuation: relayContinuation)
      session.delegate = relay
      self.relay = relay

      relayTask = Task { [weak self] in
         for await event in relayStream {
            guard let self else { return }
            self.handle(event)
         }
      }
   }

   /// watchOS can end the session on its own — a failed sensor, a dead battery
   /// saver. Either way the local state must follow, or the next start would find
   /// a session it thinks is still live.
   private func handle(_ event: RideWatchSensorEvent) {
      switch event {
         case .ended:
            guard isSensing else { return }
            DebugPrint(mode: .healthKit, "Sensor session ended by watchOS")
            stopSensing()

         case .failed(let reason):
            failure = reason
            DebugPrint(mode: .healthKit, "Sensor session failed: \(reason)")
            stopSensing()
      }
   }

   // MARK: - Heart Rate

   /// Reads the samples watchOS writes while the session runs.
   ///
   /// An anchored query rather than an `HKLiveWorkoutBuilder`: the builder is the
   /// object that would eventually save a workout, and the samples are identical
   /// either way because the system is what writes them.
   private func startHeartRateStream(
      from startDate: Date,
      into continuation: AsyncStream<RideWatchHeartRateReading>.Continuation
   ) {
      let descriptor = HKAnchoredObjectQueryDescriptor(
         predicates: [
            .quantitySample(
               type: HKQuantityType(.heartRate),
               predicate: HKQuery.predicateForSamples(
                  withStart: startDate,
                  end: nil,
                  options: .strictStartDate
               )
            )
         ],
         anchor: nil
      )

      heartRateTask = Task { [weak self] in
         guard let self else { return }

         do {
            for try await result in descriptor.results(for: self.healthStore) {
               if Task.isCancelled { break }

               // Batches arrive out of order often enough to matter; only the
               // newest beat is worth showing.
               guard let newest = result.addedSamples.max(by: { $0.startDate < $1.startDate }) else {
                  continue
               }

               continuation.yield(
                  RideWatchHeartRateReading(
                     beatsPerMinute: newest.quantity.doubleValue(for: .beatsPerMinute),
                     measuredAt: newest.startDate
                  )
               )
            }
         } catch {
            self.failure = error.localizedDescription
            DebugPrint(mode: .sensors, "Heart rate query failed: \(error.localizedDescription)")
         }

         continuation.finish()
      }
   }
}
