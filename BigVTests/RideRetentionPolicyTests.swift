//
//  RideRetentionPolicyTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

struct RideRetentionPolicyTests {

   // MARK: - Sample Count

   @Test func aRideWithNoSamplesIsDiscarded() {
      #expect(
         RideRetentionPolicy.decision(distance: 0, sampleCount: 0) == .discard(.noSamples)
      )
   }

   @Test func sampleCountAloneCannotSaveARide() {
      // The observed bug: START, fix acquired, samples recorded, never moved.
      #expect(
         RideRetentionPolicy.decision(distance: 0, sampleCount: 240)
            == .discard(.insufficientDistance)
      )
   }

   @Test func gpsNoiseWithoutRealMovementIsDiscarded() {
      #expect(
         RideRetentionPolicy.decision(distance: 12.4, sampleCount: 59)
            == .discard(.insufficientDistance)
      )
   }

   // MARK: - Threshold

   @Test func justUnderTheThresholdIsDiscarded() {
      let distance = RideRetentionPolicy.minimumMeaningfulDistance - 0.01
      #expect(
         RideRetentionPolicy.decision(distance: distance, sampleCount: 30)
            == .discard(.insufficientDistance)
      )
   }

   @Test func exactlyTheThresholdIsKept() {
      #expect(
         RideRetentionPolicy.decision(
            distance: RideRetentionPolicy.minimumMeaningfulDistance,
            sampleCount: 30
         ) == .keep
      )
   }

   @Test func justOverTheThresholdIsKept() {
      let distance = RideRetentionPolicy.minimumMeaningfulDistance + 0.01
      #expect(
         RideRetentionPolicy.decision(distance: distance, sampleCount: 30) == .keep
      )
   }

   // MARK: - Legitimate Rides

   @Test func aLegitimateShortRideIsKept() {
      // 400 m round the block still counts.
      #expect(RideRetentionPolicy.decision(distance: 400, sampleCount: 90) == .keep)
   }

   @Test func aFullRideIsKept() {
      #expect(RideRetentionPolicy.decision(distance: 24_140, sampleCount: 1_800) == .keep)
   }

   // MARK: - Degenerate Input

   @Test func aNaNDistanceIsDiscarded() {
      #expect(
         RideRetentionPolicy.decision(distance: .nan, sampleCount: 30)
            == .discard(.insufficientDistance)
      )
   }

   @Test func theThresholdStaysWhereRidersExpectIt() {
      #expect(RideRetentionPolicy.minimumMeaningfulDistance == 50)
   }
}
