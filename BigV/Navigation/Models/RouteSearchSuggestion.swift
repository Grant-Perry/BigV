//
//  RouteSearchSuggestion.swift
//  BigV
//

import Foundation

/// One row of as-you-type search results.
///
/// Only what the list draws. The provider keeps whatever handle it needs to turn
/// a chosen suggestion back into a coordinate, so nothing MapKit-shaped reaches
/// the view layer.
struct RouteSearchSuggestion: Identifiable, Sendable, Hashable {

   /// Assigned by the search service and valid only for the batch it came in.
   /// Selecting a row hands this back so the service can find its own handle.
   let id: Int

   let title: String
   let subtitle: String

   var hasSubtitle: Bool { !subtitle.isEmpty }
}
