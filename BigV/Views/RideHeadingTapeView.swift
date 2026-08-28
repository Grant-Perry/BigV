//
//  RideHeadingTapeView.swift
//  BigV
//

import SwiftUI

/// Heading tape: a fixed up-arrow, and N/E/S/W sliding horizontally past it.
struct RideHeadingTapeView: View {

   let course: Double
   let heading: String
   let headingDegrees: String
   let isDimmed: Bool
   var isExpanded: Bool = false

   private var hasCourse: Bool { course >= 0 }
   private var displayCourse: Double { hasCourse ? course : 0 }
   private var visibleSpan: Double { isExpanded ? 150 : 180 }
   private var tapeHeight: CGFloat { isExpanded ? 76 : 56 }

   var body: some View {
      VStack(spacing: isExpanded ? 6 : 3) {
         Image(systemName: .lubberIcon)
            .font(.system(size: isExpanded ? 16 : 13, weight: .bold))
            .foregroundStyle(isDimmed ? .white.opacity(0.30) : RideDashboardTheme.ember)
            .accessibilityHidden(true)

         tape
            .frame(height: tapeHeight)
            .mask(edgeFade)

         readout
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Heading")
      .accessibilityValue(hasCourse ? "\(heading) \(headingDegrees)" : "Unknown")
      .accessibilityIdentifier("ride.heading")
   }

   // MARK: - Tape

   private var tape: some View {
      GeometryReader { geometry in
         let width = Double(geometry.size.width)

         ZStack {
            ticks(width: width)

            ForEach(Self.cardinals, id: \.degrees) { mark in
               if shouldShow(mark) {
                  Text(mark.label)
                     .font(ordinalFont(isPrimary: mark.isPrimary))
                     .foregroundStyle(ordinalColor(isPrimary: mark.isPrimary))
                     .position(
                        x: CGFloat(RideHeadingTapeGeometry.xPosition(
                           heading: mark.degrees,
                           course: displayCourse,
                           width: width,
                           visibleSpan: visibleSpan
                        )),
                        y: geometry.size.height * 0.36
                     )
               }
            }

            Capsule()
               .fill(isDimmed ? .white.opacity(0.28) : RideDashboardTheme.ember)
               .frame(width: 2, height: isExpanded ? 12 : 9)
               .position(x: geometry.size.width / 2, y: geometry.size.height - 6)
         }
      }
   }

   private func ticks(width: Double) -> some View {
      Canvas { context, size in
         let tickStep = isExpanded ? 5 : 15
         let start = alignedFloor(Int((displayCourse - visibleSpan / 2).rounded(.down)), step: tickStep)
         let end = Int((displayCourse + visibleSpan / 2).rounded(.up))

         for raw in stride(from: start, through: end, by: tickStep) {
            let heading = RideHeadingTapeGeometry.normalized(Double(raw))
            let x = CGFloat(RideHeadingTapeGeometry.xPosition(
               heading: heading,
               course: displayCourse,
               width: width,
               visibleSpan: visibleSpan
            ))
            guard x >= -4, x <= size.width + 4 else { continue }

            let isCardinal = raw.isMultiple(of: 90)
            let isIntercardinal = raw.isMultiple(of: 45)
            let tickHeight = self.tickHeight(isCardinal: isCardinal, isIntercardinal: isIntercardinal)
            var tick = Path()
            tick.addRoundedRect(
               in: CGRect(
                  x: x - 0.75,
                  y: size.height - tickHeight,
                  width: 1.5,
                  height: tickHeight
               ),
               cornerSize: CGSize(width: 0.75, height: 0.75)
            )
            context.fill(tick, with: .color(tickColor(isCardinal: isCardinal)))
         }
      }
   }

   // MARK: - Readout

   private var readout: some View {
      HStack(alignment: .firstTextBaseline, spacing: isExpanded ? 10 : 6) {
         Text(heading)
            .font(isExpanded ? .title2.weight(.bold) : .subheadline.weight(.bold))
            .kerning(0.6)
            .foregroundStyle(isDimmed ? .white.opacity(0.35) : RideDashboardTheme.ice)

         if hasCourse {
            Text(headingDegrees)
               .font(isExpanded ? .title3.weight(.semibold) : .caption.weight(.semibold))
               .monospacedDigit()
               .foregroundStyle(isDimmed ? .white.opacity(0.22) : .white.opacity(0.62))
         }
      }
   }

   private var edgeFade: some View {
      LinearGradient(
         stops: [
            .init(color: .clear, location: 0),
            .init(color: .white, location: 0.10),
            .init(color: .white, location: 0.90),
            .init(color: .clear, location: 1)
         ],
         startPoint: .leading,
         endPoint: .trailing
      )
   }

   // MARK: - Marks

   private struct CardinalMark: Sendable {
      let degrees: Double
      let label: String
      let isPrimary: Bool
   }

   private static let cardinals: [CardinalMark] = [
      CardinalMark(degrees: 0, label: "N", isPrimary: true),
      CardinalMark(degrees: 45, label: "NE", isPrimary: false),
      CardinalMark(degrees: 90, label: "E", isPrimary: true),
      CardinalMark(degrees: 135, label: "SE", isPrimary: false),
      CardinalMark(degrees: 180, label: "S", isPrimary: true),
      CardinalMark(degrees: 225, label: "SW", isPrimary: false),
      CardinalMark(degrees: 270, label: "W", isPrimary: true),
      CardinalMark(degrees: 315, label: "NW", isPrimary: false)
   ]

   private func shouldShow(_ mark: CardinalMark) -> Bool {
      guard mark.isPrimary || isExpanded else { return false }
      return RideHeadingTapeGeometry.isVisible(
         heading: mark.degrees,
         course: displayCourse,
         visibleSpan: visibleSpan
      )
   }

   private func ordinalFont(isPrimary: Bool) -> Font {
      if isPrimary {
         return .system(size: isExpanded ? 36 : 26, weight: .heavy, design: .rounded)
      }
      return .system(size: isExpanded ? 18 : 14, weight: .bold, design: .rounded)
   }

   private func ordinalColor(isPrimary: Bool) -> Color {
      if isDimmed {
         return .white.opacity(isPrimary ? 0.45 : 0.24)
      }
      return isPrimary ? .white : .white.opacity(0.62)
   }

   private func tickHeight(isCardinal: Bool, isIntercardinal: Bool) -> CGFloat {
      if isCardinal { return isExpanded ? 14 : 10 }
      if isIntercardinal { return isExpanded ? 9 : 6 }
      return isExpanded ? 5 : 4
   }

   private func tickColor(isCardinal: Bool) -> Color {
      if isDimmed {
         return .white.opacity(isCardinal ? 0.28 : 0.12)
      }
      return isCardinal ? RideDashboardTheme.ice.opacity(0.70) : RideDashboardTheme.ice.opacity(0.32)
   }

   private func alignedFloor(_ value: Int, step: Int) -> Int {
      let remainder = ((value % step) + step) % step
      return value - remainder
   }
}

private extension String {
   static let lubberIcon = "location.north.fill"
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      VStack(spacing: 24) {
         RideHeadingTapeView(
            course: 47,
            heading: "NE",
            headingDegrees: "47°",
            isDimmed: false
         )
         RideHeadingTapeView(
            course: 47,
            heading: "NE",
            headingDegrees: "47°",
            isDimmed: false,
            isExpanded: true
         )
      }
      .padding()
   }
}
