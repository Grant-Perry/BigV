//
//  RideStorageManager.swift
//  BigV
//

import Foundation
import SwiftData

/// Owns every SwiftData write for rides.
///
/// BigV is the system of record, so a ride row exists from the moment recording
/// begins and grows as the engine accepts samples. Nothing else in the app is
/// allowed to insert, mutate or delete `Ride` or `RideSample`.
@MainActor
final class RideStorageManager {

   // MARK: - Failure Surface

   /// Description of the most recent failed save, cleared by the next success.
   private(set) var lastFailure: String?

   var hasFailure: Bool { lastFailure != nil }

   // MARK: - Dependencies

   private let modelContext: ModelContext

   // MARK: - Private State

   private var activeRide: Ride?
   private var unsavedSampleCount = 0
   private var lastSaveDate = Date.distantPast

   /// Samples arrive at roughly 1 Hz for hours. Committing each one hammers the
   /// store for no benefit, so a save is forced after this many samples or this
   /// many seconds, whichever comes first, plus immediately on pause, end and
   /// backgrounding. Worst case a hard crash costs the last few seconds of a
   /// ride instead of the ride itself.
   private let saveSampleThreshold = 10
   private let saveInterval: TimeInterval = 10

   // MARK: - Initialization

   init(modelContext: ModelContext) {
      self.modelContext = modelContext
   }

   // MARK: - Ride Lifecycle

   /// Creates the ride row. Called when the engine acquires its first fix.
   func beginRide(startDate: Date) {
      guard activeRide == nil else { return }

      let ride = Ride(startDate: startDate)
      modelContext.insert(ride)
      activeRide = ride
      unsavedSampleCount = 0

      save(reason: "ride created")
   }

   /// Closes out the active ride and returns it for export.
   ///
   /// A ride `RideRetentionPolicy` rejects is discarded rather than left to
   /// clutter history, and `nil` tells the caller there is nothing to export.
   @discardableResult
   func finalizeRide(with state: RideState) -> Ride? {
      guard let ride = activeRide else { return nil }
      activeRide = nil

      let decision = RideRetentionPolicy.decision(
         distance: state.distance,
         sampleCount: ride.samples.count
      )

      if case .discard(let reason) = decision {
         discard(ride, reason: reason)
         return nil
      }

      apply(state, to: ride)
      ride.endDate = state.endDate ?? .now
      ride.averageHeartRate = Self.averageHeartRate(of: ride.samples)
      save(reason: "ride finalized")

      return ride
   }

   /// Mean of every sample that carried a pulse. `nil` when no Watch or strap
   /// fed one, so the detail screen never shows a zero heart.
   private static func averageHeartRate(of samples: [RideSample]) -> Double? {
      let beats = samples.compactMap(\.heartRate).filter { $0 > 0 }
      guard !beats.isEmpty else { return nil }
      return beats.reduce(0, +) / Double(beats.count)
   }

   /// Drops the in-progress ride without finalizing it. Used when the session
   /// has already decided the ride is not worth keeping.
   func discardActiveRide(reason: RideRetentionPolicy.DiscardReason) {
      guard let ride = activeRide else { return }
      activeRide = nil

      discard(ride, reason: reason)
   }

   private func discard(_ ride: Ride, reason: RideRetentionPolicy.DiscardReason) {
      // `Ride.samples` cascades, so the samples go with the row.
      modelContext.delete(ride)
      unsavedSampleCount = 0
      save(reason: "ride discarded (\(reason.rawValue))")
   }

   // MARK: - Samples

   func append(_ draft: RideSampleDraft, totals: RideState) {
      guard let ride = activeRide else { return }

      let sample = RideSample(
         timestamp: draft.timestamp,
         latitude: draft.latitude,
         longitude: draft.longitude,
         altitude: draft.altitude,
         speed: draft.speed,
         distance: draft.distance,
         grade: draft.grade,
         course: draft.course
      )
      sample.heartRate = draft.heartRate
      sample.ride = ride
      modelContext.insert(sample)

      apply(totals, to: ride)
      unsavedSampleCount += 1

      saveIfDue()
   }

   // MARK: - Radar Passes

   /// Records one completed vehicle pass and folds it into the ride's totals.
   ///
   /// Passes arrive at road frequency — dozens per ride, not thousands — so
   /// they ride the same batching as samples rather than forcing a save each:
   /// the next sample batch or `flush()` commits them within seconds.
   func appendRadarPass(
      _ pass: RideRadarTracker.Pass,
      latitude: Double?,
      longitude: Double?
   ) {
      guard let ride = activeRide else { return }

      let event = RideRadarEvent(
         timestamp: pass.lastSeenAt,
         trackID: Int(pass.trackID),
         minimumDistance: pass.minimumDistanceMeters,
         maximumClosingSpeed: pass.maximumClosingSpeedMetersPerSecond,
         peakTier: pass.peakTier,
         latitude: latitude,
         longitude: longitude
      )
      event.ride = ride
      modelContext.insert(event)

      ride.vehicleCount += 1
      ride.closestPassDistance = min(
         ride.closestPassDistance ?? .greatestFiniteMagnitude,
         pass.minimumDistanceMeters
      )
      ride.maximumClosingSpeed = max(
         ride.maximumClosingSpeed ?? 0,
         pass.maximumClosingSpeedMetersPerSecond
      )

      saveIfDue()
   }

   // MARK: - Flushing

   /// Commits anything pending. Used on pause, end and scene backgrounding.
   func flush() {
      guard activeRide != nil else { return }
      save(reason: "flush")
   }

   // MARK: - Active Ride Charts

   /// Samples for the ride being recorded, sorted oldest-first.
   ///
   /// Only used while a live metric chart is open; never called on every GPS tick
   /// unless the cockpit has a metric selected.
   func activeRideChartSamples() -> (startDate: Date, samples: [RideSample])? {
      guard let ride = activeRide else { return nil }

      let samples = ride.samples.sorted { $0.timestamp < $1.timestamp }
      return (ride.startDate, samples)
   }

   /// Cheap signal for throttling live chart rebuilds.
   var activeSampleCount: Int {
      activeRide?.samples.count ?? 0
   }

   /// Radar passes on the ride being recorded, for the live traffic timeline.
   func activeRideRadarContext() -> (
      startDate: Date,
      events: [RideRadarEvent],
      vehicleCount: Int,
      closestPassDistance: Double?,
      maximumClosingSpeed: Double?,
      distanceMeters: Double
   )? {
      guard let ride = activeRide else { return nil }

      return (
         ride.startDate,
         ride.radarEvents.sorted { $0.timestamp < $1.timestamp },
         ride.vehicleCount,
         ride.closestPassDistance,
         ride.maximumClosingSpeed,
         ride.distance
      )
   }

   // MARK: - History

   func savedRides() -> [Ride] {
      let descriptor = FetchDescriptor<Ride>(
         sortBy: [SortDescriptor(\.startDate, order: .reverse)]
      )

      do {
         return try modelContext.fetch(descriptor)
      } catch {
         record(error, reason: "ride fetch")
         return []
      }
   }

   func ride(with identifier: PersistentIdentifier) -> Ride? {
      var descriptor = FetchDescriptor<Ride>(
         predicate: #Predicate { $0.persistentModelID == identifier }
      )
      descriptor.fetchLimit = 1

      do {
         return try modelContext.fetch(descriptor).first
      } catch {
         record(error, reason: "ride lookup")
         return nil
      }
   }

   func delete(_ ride: Ride) {
      modelContext.delete(ride)
      save(reason: "ride deleted")
   }

   // MARK: - Backup Import

   /// Inserts a finished ride from a Settings backup. Caller is responsible for
   /// duplicate checks; this path always inserts.
   func importFinishedRide(_ record: RideBackupPayload.RideRecord) {
      let ride = Ride(startDate: record.startDate, name: record.name)
      ride.endDate = record.endDate
      ride.duration = record.duration
      ride.movingTime = record.movingTime
      ride.distance = record.distance
      ride.averageSpeed = record.averageSpeed
      ride.maximumSpeed = record.maximumSpeed
      ride.elevationGain = record.elevationGain
      ride.elevationLoss = record.elevationLoss
      ride.activeEnergy = record.activeEnergy
      ride.averageHeartRate = record.averageHeartRate
      ride.averageCadence = record.averageCadence
      ride.averagePower = record.averagePower
      ride.vehicleCount = record.vehicleCount
      ride.closestPassDistance = record.closestPassDistance
      ride.maximumClosingSpeed = record.maximumClosingSpeed
      ride.weatherSymbolName = record.weatherSymbolName
      ride.weatherConditionLabel = record.weatherConditionLabel
      ride.startTemperatureCelsius = record.startTemperatureCelsius
      ride.startApparentTemperatureCelsius = record.startApparentTemperatureCelsius
      ride.windSpeedKilometersPerHour = record.windSpeedKilometersPerHour
      ride.endTemperatureCelsius = record.endTemperatureCelsius

      modelContext.insert(ride)

      for sampleRecord in record.samples {
         let sample = RideSample(
            timestamp: sampleRecord.timestamp,
            latitude: sampleRecord.latitude,
            longitude: sampleRecord.longitude,
            altitude: sampleRecord.altitude,
            speed: sampleRecord.speed,
            distance: sampleRecord.distance,
            grade: sampleRecord.grade,
            course: sampleRecord.course
         )
         sample.heartRate = sampleRecord.heartRate
         sample.cadence = sampleRecord.cadence
         sample.power = sampleRecord.power
         sample.ride = ride
         modelContext.insert(sample)
      }

      for eventRecord in record.radarEvents {
         let tier = RideRadarThreatTier(rawValue: eventRecord.peakTierRawValue) ?? .approaching
         let event = RideRadarEvent(
            timestamp: eventRecord.timestamp,
            trackID: eventRecord.trackID,
            minimumDistance: eventRecord.minimumDistance,
            maximumClosingSpeed: eventRecord.maximumClosingSpeed,
            peakTier: tier,
            latitude: eventRecord.latitude,
            longitude: eventRecord.longitude
         )
         event.ride = ride
         modelContext.insert(event)
      }

      save(reason: "backup import")
   }

   // MARK: - Export Links

   func linkHealthKitWorkout(_ identifier: UUID, to ride: Ride) {
      ride.healthKitWorkoutID = identifier
      save(reason: "HealthKit link")
   }

   // MARK: - Weather

   /// Stamps the sky onto the ride being recorded. Arrives whenever the
   /// WeatherKit fetch lands, so a ride that ends first is stamped through
   /// `applyEndWeather` instead and this becomes a no-op.
   func applyStartWeather(_ snapshot: RideWeatherSnapshot) {
      guard let ride = activeRide else { return }

      ride.weatherSymbolName = snapshot.symbolName
      ride.weatherConditionLabel = snapshot.conditionLabel
      ride.startTemperatureCelsius = snapshot.temperatureCelsius
      ride.startApparentTemperatureCelsius = snapshot.apparentTemperatureCelsius
      ride.windSpeedKilometersPerHour = snapshot.windSpeedKilometersPerHour
      save(reason: "start weather")
   }

   /// Stamps end-of-ride conditions onto an already-finalized ride, and fills
   /// any start fields a failed or unfinished start fetch left empty.
   func applyEndWeather(_ snapshot: RideWeatherSnapshot, to ride: Ride) {
      ride.endTemperatureCelsius = snapshot.temperatureCelsius

      if ride.weatherSymbolName == nil {
         ride.weatherSymbolName = snapshot.symbolName
         ride.weatherConditionLabel = snapshot.conditionLabel
         ride.startTemperatureCelsius = snapshot.temperatureCelsius
         ride.startApparentTemperatureCelsius = snapshot.apparentTemperatureCelsius
         ride.windSpeedKilometersPerHour = snapshot.windSpeedKilometersPerHour
      }

      save(reason: "end weather")
   }

   // MARK: - Totals

   private func apply(_ state: RideState, to ride: Ride) {
      ride.duration = state.elapsedTime
      ride.movingTime = state.movingTime
      ride.distance = state.distance
      ride.averageSpeed = state.averageSpeed
      ride.maximumSpeed = state.maximumSpeed
      ride.elevationGain = state.elevationGain
      ride.elevationLoss = state.elevationLoss
   }

   // MARK: - Saving

   private func saveIfDue() {
      guard unsavedSampleCount >= saveSampleThreshold
               || Date.now.timeIntervalSince(lastSaveDate) >= saveInterval
      else { return }

      save(reason: "batch")
   }

   private func save(reason: String) {
      guard modelContext.hasChanges else {
         unsavedSampleCount = 0
         lastSaveDate = .now
         return
      }

      do {
         try modelContext.save()
         unsavedSampleCount = 0
         lastSaveDate = .now
         lastFailure = nil

         DebugPrint(mode: .persistence, "Saved: \(reason)")
      } catch {
         record(error, reason: reason)
      }
   }

   private func record(_ error: Error, reason: String) {
      lastFailure = error.localizedDescription
      DebugPrint(mode: .persistence, "Failed (\(reason)): \(error.localizedDescription)")
   }
}
