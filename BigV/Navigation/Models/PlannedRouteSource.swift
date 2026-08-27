//
//  PlannedRouteSource.swift
//  BigV
//

import Foundation

/// Which provider produced a planned route.
///
/// Carried on the route so guidance never has to ask where the geometry came
/// from, and so a rider can be told who is claiming a distance or an ETA. New
/// providers are added here and in a `PlannedRouteProviding` conformance; nothing
/// downstream changes.
enum PlannedRouteSource: String, Sendable, CaseIterable {

   case appleMaps

   /// Reserved for a route read from a file. No importer exists yet.
   case gpx

   /// Reserved for a trail fetched from Trailforks. Pending licensing review.
   case trailforks
}
