//
//  RideLapsCard.swift
//  BigV
//

import SwiftUI

/// The ride cut into pieces: manual and auto laps first, then every climb the
/// ride recorded. On the detail report the rows are a piano — tap to pin a
/// split on the map, hold and slide to scrub.
struct RideLapsCard: View {

   let report: RideLapsReport

   @Binding private var highlightedSplit: RideSplitID?
   @Binding private var isScrubbing: Bool
   private let isInteractive: Bool

   @State private var rowFrames: [RideSplitID: CGRect] = [:]

   init(report: RideLapsReport) {
      self.report = report
      _highlightedSplit = .constant(nil)
      _isScrubbing = .constant(false)
      isInteractive = false
   }

   init(
      report: RideLapsReport,
      highlightedSplit: Binding<RideSplitID?>,
      isScrubbing: Binding<Bool>
   ) {
      self.report = report
      _highlightedSplit = highlightedSplit
      _isScrubbing = isScrubbing
      isInteractive = true
   }

   var body: some View {
      VStack(alignment: .leading, spacing: 12) {
         RideDetailCardHeader(
            icon: "flag.fill",
            tint: RideDashboardTheme.ember,
            title: "LAPS & CLIMBS",
            detail: report.summaryText
         )

         scrubbableRows
      }
      .padding(14)
      .rideGlassCard(density: .standard)
      .sensoryFeedback(.selection, trigger: highlightedSplit)
      .accessibilityIdentifier("detail.card.laps")
   }

   // MARK: - Rows

   @ViewBuilder
   private var scrubbableRows: some View {
      let stack = rows
         .coordinateSpace(name: Self.scrubSpace)
         .onPreferenceChange(RideLapsRowFrameKey.self) { rowFrames = $0 }

      if isInteractive {
         stack.gesture(scrubGesture)
      } else {
         stack
      }
   }

   private var rows: some View {
      VStack(spacing: 8) {
         ForEach(report.lapRows) { row in
            splitRow(row, id: .lap(row.id), badgeTint: RideDashboardTheme.ice)
         }

         if !report.lapRows.isEmpty, !report.climbRows.isEmpty {
            Rectangle()
               .fill(RideDashboardTheme.ink(0.08))
               .frame(height: 1)
         }

         ForEach(report.climbRows) { row in
            splitRow(row, id: .climb(row.id), badgeTint: RideDashboardTheme.ember)
         }
      }
   }

   @ViewBuilder
   private func splitRow(
      _ row: RideLapsReport.Row,
      id: RideSplitID,
      badgeTint: Color
   ) -> some View {
      let rowView = RideLapsRow(
         row: row,
         splitID: id,
         badgeTint: badgeTint,
         isHighlighted: highlightedSplit == id,
         action: isInteractive ? { toggle(id) } : nil
      )
      .background {
         GeometryReader { proxy in
            Color.clear.preference(
               key: RideLapsRowFrameKey.self,
               value: [id: proxy.frame(in: .named(Self.scrubSpace))]
            )
         }
      }

      if isInteractive {
         rowView.simultaneousGesture(pinGesture(for: id))
      } else {
         rowView
      }
   }

   // MARK: - Gestures

   /// Hold still on a row to pin it before the finger starts traveling.
   /// Scroll stays free until the sequenced drag actually moves.
   private func pinGesture(for id: RideSplitID) -> some Gesture {
      LongPressGesture(minimumDuration: 0.22)
         .onEnded { _ in
            highlightedSplit = id
         }
   }

   /// After the hold, a drag across the stack is a piano, not a scroll.
   private var scrubGesture: some Gesture {
      LongPressGesture(minimumDuration: 0.22)
         .sequenced(
            before: DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.scrubSpace))
         )
         .onChanged { value in
            guard isInteractive else { return }
            if case .second(true, let drag) = value, let drag {
               isScrubbing = true
               highlight(at: drag.location)
            }
         }
         .onEnded { _ in
            isScrubbing = false
         }
   }

   // MARK: - Intent

   private func toggle(_ id: RideSplitID) {
      highlightedSplit = highlightedSplit == id ? nil : id
   }

   private func highlight(at point: CGPoint) {
      if let id = RideLapsScrub.split(at: point, frames: rowFrames) {
         highlightedSplit = id
      }
   }

   private static let scrubSpace = "lapsScrub"
}

// MARK: - Row frames

private struct RideLapsRowFrameKey: PreferenceKey {
   static var defaultValue: [RideSplitID: CGRect] = [:]

   static func reduce(value: inout [RideSplitID: CGRect], nextValue: () -> [RideSplitID: CGRect]) {
      value.merge(nextValue(), uniquingKeysWith: { $1 })
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground(scene: .summary)
      RideLapsCard(
         report: RideLapsReport(
            lapRows: [
               RideLapsReport.Row(id: 1, badge: "LAP 1", timeText: "22:41", distanceText: "5.0 MI", detailText: "13.2 MPH · +320 FT"),
               RideLapsReport.Row(id: 2, badge: "LAP 2", timeText: "24:05", distanceText: "5.0 MI", detailText: "12.5 MPH · +410 FT")
            ],
            climbRows: [
               RideLapsReport.Row(id: 1, badge: "CAT 3", timeText: "11:32", distanceText: "1.8 MI", detailText: "+540 FT @ 5.4% · 850 VAM")
            ],
            summaryText: "2 LAPS · 1 CLIMB"
         )
      )
      .padding()
   }
   .preferredColorScheme(.dark)
}
