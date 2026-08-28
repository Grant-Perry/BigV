//
//  HKUnit+HeartRate.swift
//  BigV Watch App
//

import HealthKit

nonisolated extension HKUnit {

   /// The unit every heart rate sample HealthKit stores is expressed in.
   static let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())
}
