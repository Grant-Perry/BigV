//
//  RideSplitWindow.swift
//  BigV
//

import Foundation

/// The stored bounds of one lap or climb, before they become a map slice.
struct RideSplitWindow: Sendable, Equatable {
   let id: RideSplitID
   let startDistance: Double
   let endDistance: Double
   let startDate: Date
   let endDate: Date
}
