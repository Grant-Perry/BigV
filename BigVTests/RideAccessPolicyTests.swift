//
//  RideAccessPolicyTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

struct RideAccessPolicyTests {

   private let began = Date(timeIntervalSince1970: 1_700_000_000)

   @Test func aPaidRiderCanAlwaysBegin() {
      let later = began.addingTimeInterval(RideAccessPolicy.trialLength * 4)
      let status = RideAccessPolicy.status(
         trialBeganAt: began,
         isSubscribed: true,
         now: later
      )

      #expect(status == .subscribed)
      #expect(RideAccessPolicy.canBeginRide(status))
   }

   @Test func dayZeroHasThirtyDaysLeft() {
      let status = RideAccessPolicy.status(
         trialBeganAt: began,
         isSubscribed: false,
         now: began
      )

      #expect(status == .trial(daysRemaining: 30))
      #expect(RideAccessPolicy.canBeginRide(status))
   }

   @Test func theLastHourStillCountsAsOneDay() {
      let now = began.addingTimeInterval(RideAccessPolicy.trialLength - 3_600)
      let status = RideAccessPolicy.status(
         trialBeganAt: began,
         isSubscribed: false,
         now: now
      )

      #expect(status == .trial(daysRemaining: 1))
      #expect(RideAccessPolicy.canBeginRide(status))
   }

   @Test func theThirtiethDayEndsTheTrial() {
      let now = began.addingTimeInterval(RideAccessPolicy.trialLength)
      let status = RideAccessPolicy.status(
         trialBeganAt: began,
         isSubscribed: false,
         now: now
      )

      #expect(status == .expired)
      #expect(RideAccessPolicy.canBeginRide(status) == false)
   }
}
