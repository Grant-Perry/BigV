//
//  RideSessionManagerTests.swift
//  BigVTests
//

import Testing
@testable import BigV

@MainActor
struct RideSessionManagerTests {

   private var preciseAccuracy: Double {
      RideTelemetryEngine.Configuration.default.maxHorizontalAccuracy
   }

   @Test func preciseFixesRecordATrackCoordinate() {
      #expect(
         RideSessionManager.recordsTrackCoordinate(
            .accepted,
            horizontalAccuracy: 5,
            preciseHorizontalAccuracy: preciseAccuracy
         )
      )
      #expect(
         RideSessionManager.recordsTrackCoordinate(
            .accepted,
            horizontalAccuracy: preciseAccuracy,
            preciseHorizontalAccuracy: preciseAccuracy
         )
      )
      #expect(
         RideSessionManager.recordsTrackCoordinate(
            .acquiredFix,
            horizontalAccuracy: 8,
            preciseHorizontalAccuracy: preciseAccuracy
         )
      )
      #expect(
         RideSessionManager.recordsTrackCoordinate(
            .reseeded,
            horizontalAccuracy: 12,
            preciseHorizontalAccuracy: preciseAccuracy
         )
      )
   }

   @Test func coarseFixesDoNotRecordATrackCoordinate() {
      #expect(
         !RideSessionManager.recordsTrackCoordinate(
            .acceptedCoarse,
            horizontalAccuracy: 40,
            preciseHorizontalAccuracy: preciseAccuracy
         )
      )
      #expect(
         !RideSessionManager.recordsTrackCoordinate(
            .acceptedCoarse,
            horizontalAccuracy: 65,
            preciseHorizontalAccuracy: preciseAccuracy
         )
      )
      #expect(
         !RideSessionManager.recordsTrackCoordinate(
            .acquiredFix,
            horizontalAccuracy: 40,
            preciseHorizontalAccuracy: preciseAccuracy
         )
      )
      #expect(
         !RideSessionManager.recordsTrackCoordinate(
            .reseeded,
            horizontalAccuracy: preciseAccuracy + 1,
            preciseHorizontalAccuracy: preciseAccuracy
         )
      )
      #expect(
         !RideSessionManager.recordsTrackCoordinate(
            .rejected(.poorAccuracy),
            horizontalAccuracy: 80,
            preciseHorizontalAccuracy: preciseAccuracy
         )
      )
   }
}
