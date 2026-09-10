//
//  RideSplitSegment.swift
//  BigV
//

import Foundation

/// A lap or climb that can be drawn on the saved-ride map.
struct RideSplitSegment: Identifiable {

   let id: RideSplitID
   let route: RideRoute
}
