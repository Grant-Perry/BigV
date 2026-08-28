//
//  RideRadarSimulator.swift
//  BigV
//

import Foundation

/// Scripted radar traffic on the same event stream the real manager uses.
///
/// The session cannot tell script from hardware, which is the point: the whole
/// UI can be built, demoed and reviewed with no radar on the desk. Scenarios
/// are generated as raw wire payloads and pushed through `RideRadarDecoder`,
/// so the simulator exercises the actual decode path rather than a shortcut.
nonisolated enum RideRadarSimulator {

   // MARK: - Scenarios

   enum Scenario: String, CaseIterable, Sendable {

      /// One car from 120 m closing hard, past, gone. The canonical overtake.
      case singleFastOvertake

      /// Three cars, staggered entries, different speeds.
      case threeCarCluster

      /// One car parked in the draft at 12–15 m for twenty seconds.
      case sustainedTailgater

      /// Heartbeats only. An empty road.
      case allClear
   }

   /// One wire payload at an offset from scenario start.
   struct ScriptStep: Sendable, Equatable {
      let offset: TimeInterval
      let payload: [UInt8]
   }

   /// The radar notifies at roughly 7 Hz.
   static let reportInterval: TimeInterval = 1.0 / 7.0

   private static let simulatedBatteryPercent = 87

   // MARK: - Event Stream

   /// The seam. `RideRadarManager` will expose the same shape from Core Bluetooth.
   static func events(for scenario: Scenario) -> AsyncStream<RideRadarLinkEvent> {
      AsyncStream(bufferingPolicy: .bufferingNewest(16)) { continuation in
         let task = Task {
            continuation.yield(.connection(.connected))
            continuation.yield(.battery(simulatedBatteryPercent))

            await play(script(for: scenario), into: continuation)

            continuation.finish()
         }

         continuation.onTermination = { _ in task.cancel() }
      }
   }

   /// Every scenario back to back, forever. The App Review demo path.
   static func demoLoop() -> AsyncStream<RideRadarLinkEvent> {
      AsyncStream(bufferingPolicy: .bufferingNewest(16)) { continuation in
         let task = Task {
            continuation.yield(.connection(.connected))
            continuation.yield(.battery(simulatedBatteryPercent))

            while !Task.isCancelled {
               for scenario in Scenario.allCases {
                  await play(script(for: scenario), into: continuation)
                  guard !Task.isCancelled else { break }
               }
            }

            continuation.finish()
         }

         continuation.onTermination = { _ in task.cancel() }
      }
   }

   private static func play(
      _ steps: [ScriptStep],
      into continuation: AsyncStream<RideRadarLinkEvent>.Continuation
   ) async {
      var elapsed: TimeInterval = 0

      for step in steps {
         let wait = step.offset - elapsed
         if wait > 0 {
            try? await Task.sleep(for: .seconds(wait))
         }
         guard !Task.isCancelled else { return }
         elapsed = step.offset

         if let frame = decodeStep(step) {
            continuation.yield(.frame(frame))
         }
      }
   }

   private static func decodeStep(_ step: ScriptStep) -> RideRadarFrame? {
      switch RideRadarDecoder.classify(step.payload) {
         case .heartbeat(let frame), .threat(let frame): frame
         case .sectorAmplitude, .unknown: nil
      }
   }

   // MARK: - Scripts

   /// Pure and deterministic, so tests can decode every step without waiting.
   static func script(for scenario: Scenario) -> [ScriptStep] {
      switch scenario {
         case .singleFastOvertake: singleFastOvertakeScript()
         case .threeCarCluster: threeCarClusterScript()
         case .sustainedTailgater: sustainedTailgaterScript()
         case .allClear: heartbeats(from: 0, duration: 10)
      }
   }

   private static func singleFastOvertakeScript() -> [ScriptStep] {
      var steps: [ScriptStep] = []
      var sequence = SequenceCounter()
      var offset: TimeInterval = 0
      var distance = 120.0

      // 10 m/s closing until the car is on the wheel.
      while distance > 2 {
         steps.append(
            ScriptStep(offset: offset, payload: threatPayload(sequence.next(), cars: [(0x21, distance)]))
         )
         offset += reportInterval
         distance -= 10 * reportInterval
      }

      steps.append(contentsOf: heartbeats(from: offset, duration: 4, sequence: &sequence))
      return steps
   }

   private static func threeCarClusterScript() -> [ScriptStep] {
      var steps: [ScriptStep] = []
      var sequence = SequenceCounter()
      var offset: TimeInterval = 0

      // (track id, entry time, entry distance, closing speed m/s)
      let cars: [(id: UInt8, entersAt: TimeInterval, from: Double, speed: Double)] = [
         (0x31, 0, 130, 9),
         (0x32, 2, 135, 6),
         (0x33, 4, 125, 4)
      ]

      while offset < 26 {
         let visible: [(UInt8, Double)] = cars.compactMap { car in
            guard offset >= car.entersAt else { return nil }
            let distance = car.from - car.speed * (offset - car.entersAt)
            guard distance > 2 else { return nil }
            return (car.id, distance)
         }

         let payload = visible.isEmpty
            ? heartbeatPayload(sequence.next())
            : threatPayload(sequence.next(), cars: visible)

         steps.append(ScriptStep(offset: offset, payload: payload))
         offset += reportInterval
      }

      steps.append(contentsOf: heartbeats(from: offset, duration: 4, sequence: &sequence))
      return steps
   }

   private static func sustainedTailgaterScript() -> [ScriptStep] {
      var steps: [ScriptStep] = []
      var sequence = SequenceCounter()
      var offset: TimeInterval = 0

      // Drifts between 12 and 15 m — present, irritating, never escalating.
      while offset < 20 {
         let distance = 13.5 + 1.5 * sin(offset * 0.8)
         steps.append(
            ScriptStep(offset: offset, payload: threatPayload(sequence.next(), cars: [(0x44, distance)]))
         )
         offset += reportInterval
      }

      steps.append(contentsOf: heartbeats(from: offset, duration: 4, sequence: &sequence))
      return steps
   }

   // MARK: - Wire Assembly

   private static func heartbeats(
      from start: TimeInterval,
      duration: TimeInterval
   ) -> [ScriptStep] {
      var sequence = SequenceCounter()
      return heartbeats(from: start, duration: duration, sequence: &sequence)
   }

   private static func heartbeats(
      from start: TimeInterval,
      duration: TimeInterval,
      sequence: inout SequenceCounter
   ) -> [ScriptStep] {
      stride(from: start, to: start + duration, by: reportInterval).map { offset in
         ScriptStep(offset: offset, payload: heartbeatPayload(sequence.next()))
      }
   }

   private static func heartbeatPayload(_ sequence: UInt8) -> [UInt8] {
      [(sequence << 4) | 0x02]
   }

   private static func threatPayload(_ sequence: UInt8, cars: [(id: UInt8, distance: Double)]) -> [UInt8] {
      var payload: [UInt8] = [(sequence << 4) | 0x02]

      for car in cars.prefix(RideRadarDecoder.maxTargetsPerNotification) {
         payload.append(car.id | 0x80)
         payload.append(UInt8(min(max(car.distance.rounded(), 1), 254)))
         payload.append(0x00)
      }

      return payload
   }

   private struct SequenceCounter {
      private var value: UInt8 = 0

      mutating func next() -> UInt8 {
         defer { value = (value + 1) & 0x0F }
         return value
      }
   }
}
