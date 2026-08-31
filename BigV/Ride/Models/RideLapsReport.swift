//
//  RideLapsReport.swift
//  BigV
//

import Foundation

/// The laps and climb splits of one saved ride, formatted for the card.
///
/// Built by `RideLapsReportBuilder` and shown on the ride summary and the
/// history detail, so a lap reads identically the minute after the ride and a
/// month later.
struct RideLapsReport: Equatable {

   struct Row: Identifiable, Equatable {
      let id: Int

      /// "LAP 3" or the climb's category badge.
      let badge: String

      let timeText: String
      let distanceText: String

      /// The row's story: speed and gain for a lap, gain, grade and VAM for a
      /// climb.
      let detailText: String
   }

   let lapRows: [Row]
   let climbRows: [Row]

   /// "2 LAPS · 1 CLIMB", for the card header.
   let summaryText: String
}
