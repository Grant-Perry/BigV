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
nonisolated enum PlannedRouteSource: String, Sendable, CaseIterable {

   case appleMaps

   /// A route read from a GPX file by `GPXRouteImporter`.
   case gpx

   /// The rider's own breadcrumb, reversed — Back to Start along the same route.
   case retrace

   /// Reserved for a trail fetched from Trailforks. Pending licensing review.
   case trailforks
}
