//
//  RideLiveChartVisibilityTests.swift
//  BigVTests
//

import Testing
@testable import BigV

@MainActor
struct RideLiveChartVisibilityTests {

   @Test func timelineUnmountsWhenLeavingTheDashboard() {
      let rideViewModel = RideViewModel()

      rideViewModel.toggleLiveRadarTimeline()

      #expect(rideViewModel.isLiveRadarTimelineVisible)
      #expect(rideViewModel.showsLiveRadarTimeline)

      rideViewModel.selectedCockpitPage = .radar

      #expect(rideViewModel.isLiveRadarTimelineVisible)
      #expect(!rideViewModel.showsLiveRadarTimeline)

      rideViewModel.selectedCockpitPage = .dashboard

      #expect(rideViewModel.showsLiveRadarTimeline)
   }

   @Test func dismissingTheTimelineClearsTheCard() {
      let rideViewModel = RideViewModel()

      rideViewModel.toggleLiveRadarTimeline()
      rideViewModel.clearLiveRadarTimeline()

      #expect(!rideViewModel.isLiveRadarTimelineVisible)
      #expect(!rideViewModel.showsLiveRadarTimeline)
      #expect(rideViewModel.liveRadarReport == nil)
   }
}
