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
/// half. It does call `beginCollection` — watchOS ends a session that never
/// collects, which is how the glance used to bounce to the watch face on Start.
/// It never calls `finishWorkout`. The builder is discarded only if we tear the
/// session down for real, so Health still only gets the phone's ride.
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
/// ## The `prepare()` contract
///
/// `prepare()` moves a session from `.notStarted` to `.prepared` — and it does
/// it asynchronously, while the optical sensor spins up and any Bluetooth strap
/// connects. `startActivity(with:)` is only legal from `.prepared`. Issuing both
/// in the same breath races the two transitions, and the session that loses is
/// torn down by watchOS along with the app that owned it.
///
/// Apple fills that gap with a three second countdown. BigV has no countdown to
/// show, so it waits on the state itself and starts the moment the sensors are
/// warm.
///
/// ## Lingering sessions
///
/// watchOS preserves an active session across a crash or a force-quit and
/// relaunches the app for it. `reclaimOrphanedSession()` adopts that session
/// at launch. Ending it would dismiss the glance — the phone still has the ride.
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
   private var builder: HKLiveWorkoutBuilder?
   private var relay: RideWatchWorkoutRelay?
   private var relayTask: Task<Void, Never>?

   private var heartRateTask: Task<Void, Never>?
   private var heartRateContinuation: AsyncStream<RideWatchHeartRateReading>.Continuation?

   /// How long the sensors get to warm up before Start is called a failure.
   /// Matches the countdown Apple puts between `prepare()` and `startActivity`.
   private let warmUpWindow: Duration = .seconds(3)

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

   /// Adopts a session that outlived the app. Must run before the first
   /// `startSensing()`. Ending it here is how you bounce the rider to the face
   /// on launch.
   func reclaimOrphanedSession() async {
      guard HKHealthStore.isHealthDataAvailable(), session == nil else { return }

      do {
         guard let recovered = try await healthStore.recoverActiveWorkoutSession() else { return }

         startRelay(for: recovered)
         session = recovered
         builder = recovered.associatedWorkoutBuilder()
         isSensing = recovered.state == .running

         DebugPrint(mode: .healthKit, "Reclaimed an orphaned workout session")
      } catch {
         DebugPrint(mode: .healthKit, "Workout session recovery failed: \(error.localizedDescription)")
      }
   }

   // MARK: - Sensing

   /// Opens the sensor session and streams heart rate for as long as it runs.
   ///
   /// A parked session is resumed in place. Ending one and starting another
   /// in the same breath is exactly how watchOS decides the workout is over
   /// and throws the rider back at the watch face.
   func startSensing() async -> AsyncStream<RideWatchHeartRateReading> {
      if let session {
         switch session.state {
            case .paused:
               return resumeParkedSession(session)
            case .running:
               return attachHeartRateStream(from: .now)
            case .notStarted, .prepared:
               return await runToRunning(session)
            case .ended, .stopped:
               discardEndedSession()
            @unknown default:
               discardEndedSession()
         }
      }

      guard HKHealthStore.isHealthDataAvailable() else {
         return closedStream(failing: "Health data unavailable")
      }

      let configuration = HKWorkoutConfiguration()
      configuration.activityType = .cycling
      configuration.locationType = .outdoor

      do {
         let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
         let builder = session.associatedWorkoutBuilder()
         builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
         )

         startRelay(for: session)
         self.session = session
         self.builder = builder

         return await runToRunning(session)
      } catch {
         DebugPrint(mode: .healthKit, "Sensor session could not be created: \(error.localizedDescription)")
         return closedStream(failing: error.localizedDescription)
      }
   }

   /// Walks a session up to `.running` the way HealthKit requires, waiting out
   /// the warm-up rather than talking over it.
   private func runToRunning(_ session: HKWorkoutSession) async -> AsyncStream<RideWatchHeartRateReading> {
      if session.state == .notStarted {
         session.prepare()
         await waitForWarmSensors(on: session)
      }

      // The rider can hit CANCEL inside the warm-up window. Starting the
      // activity anyway would leave a workout running behind an idle glance.
      guard !Task.isCancelled else {
         discardEndedSession()
         return closedStream(failing: nil)
      }

      guard session.state == .prepared else {
         DebugPrint(mode: .healthKit, "Sensors never warmed — stalled at \(session.state.label)")
         discardEndedSession()
         return closedStream(failing: "Heart rate sensor did not start")
      }

      let startDate = Date.now
      session.startActivity(with: startDate)
      beginCollection(at: startDate)

      isSensing = true
      failure = nil

      DebugPrint(mode: .healthKit, "Sensor session started (no workout will be saved)")
      return attachHeartRateStream(from: startDate)
   }

   /// Polls the state rather than waiting on the delegate: the state is the
   /// contract HealthKit enforces, and a callback that never arrives must not
   /// be able to strand Start forever.
   private func waitForWarmSensors(on session: HKWorkoutSession) async {
      let deadline = ContinuousClock.now + warmUpWindow

      while session.state == .notStarted, ContinuousClock.now < deadline {
         do {
            try await Task.sleep(for: .milliseconds(50))
         } catch {
            return
         }
      }
   }

   /// Pauses the HealthKit session without ending it.
   ///
   /// `HKWorkoutSession.end()` dismisses the Watch app. Pause and End on the
   /// remote must never do that while the rider is still looking at the glance.
   func parkSensing() {
      detachHeartRateStream()

      guard let session, session.state == .running else {
         isSensing = false
         return
      }

      session.pause()
      isSensing = false

      DebugPrint(mode: .healthKit, "Sensor session parked")
   }

   /// Tears the session down unconditionally.
   ///
   /// `discardWorkout` plus `end()` is the only teardown. Never call this from
   /// a button or a scene-phase blip — that is how the glance used to die.
   func stopSensing() {
      detachHeartRateStream()

      relayTask?.cancel()
      relayTask = nil

      relay?.finish()
      relay = nil

      guard let session else {
         isSensing = false
         return
      }

      isSensing = false
      builder?.discardWorkout()
      builder = nil
      session.end()
      self.session = nil

      DebugPrint(mode: .healthKit, "Sensor session ended")
   }

   /// watchOS ends a session that never collects. We collect so the glance
   /// stays up; we never `finishWorkout`, so Health still only gets the phone's
   /// ride.
   private func beginCollection(at date: Date) {
      guard let builder else { return }

      Task { [weak self] in
         do {
            try await builder.beginCollection(at: date)
         } catch {
            self?.failure = error.localizedDescription
            DebugPrint(
               mode: .healthKit,
               "Workout collection failed: \(error.localizedDescription)"
            )
         }
      }
   }

   // MARK: - Park / Resume

   private func resumeParkedSession(_ session: HKWorkoutSession) -> AsyncStream<RideWatchHeartRateReading> {
      session.resume()
      isSensing = true
      failure = nil

      DebugPrint(mode: .healthKit, "Sensor session resumed from park")
      return attachHeartRateStream(from: .now)
   }

   private func attachHeartRateStream(from date: Date) -> AsyncStream<RideWatchHeartRateReading> {
      detachHeartRateStream()

      let (stream, continuation) = makeHeartRateStream()
      startHeartRateStream(from: date, into: continuation)
      isSensing = true
      return stream
   }

   /// A stream that is over before it began, so the caller's `for await` exits
   /// instead of hanging on a sensor that never came up. A `nil` reason is the
   /// rider's own cancellation, which is not a failure to report.
   private func closedStream(failing reason: String?) -> AsyncStream<RideWatchHeartRateReading> {
      detachHeartRateStream()

      isSensing = false
      failure = reason

      let (stream, continuation) = AsyncStream<RideWatchHeartRateReading>.makeStream()
      continuation.finish()
      return stream
   }

   private func makeHeartRateStream() -> (
      AsyncStream<RideWatchHeartRateReading>,
      AsyncStream<RideWatchHeartRateReading>.Continuation
   ) {
      let (stream, continuation) = AsyncStream<RideWatchHeartRateReading>.makeStream(
         bufferingPolicy: .bufferingNewest(8)
      )
      heartRateContinuation = continuation
      return (stream, continuation)
   }

   private func detachHeartRateStream() {
      heartRateTask?.cancel()
      heartRateTask = nil

      heartRateContinuation?.finish()
      heartRateContinuation = nil
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
         case .prepared:
            DebugPrint(mode: .healthKit, "Sensor session prepared")

         case .running:
            DebugPrint(mode: .healthKit, "Sensor session running")

         case .paused:
            DebugPrint(mode: .healthKit, "Sensor session paused")

         case .ended:
            DebugPrint(mode: .healthKit, "Sensor session ended by watchOS")
            discardEndedSession()

         case .failed(let reason):
            failure = reason
            DebugPrint(mode: .healthKit, "Sensor session failed: \(reason)")
            discardEndedSession()
      }
   }

   /// The session is already dead. Ending it again is how you bounce the rider
   /// off the glance.
   private func discardEndedSession() {
      detachHeartRateStream()

      relayTask?.cancel()
      relayTask = nil
      relay?.finish()
      relay = nil

      builder = nil
      session = nil
      isSensing = false
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
