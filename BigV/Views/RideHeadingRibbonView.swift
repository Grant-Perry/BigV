//
//  RideHeadingRibbonView.swift
//  BigV
//

import SwiftUI

/// Heading ribbon under the speed: a fixed green needle, and the compass
/// rose sliding past it.
///
/// Every five degrees gets a tick, every forty-five a letter, every thirty a
/// small bearing numeral, HSI-style. The cardinal under the needle flares red
/// once the bike is within five degrees of it. The rose is one animatable
/// Canvas, so each new course glides in along the shortest arc rather than
/// snapping, and a swing through north never spins the long way round.
struct RideHeadingRibbonView: View {

   /// Degrees, or negative when nothing knows which way the bike points.
   let course: Double

   /// Sixteen-point cardinal, already formatted ("NNE"), or the placeholder.
   let heading: String

   /// "47°", or the placeholder.
   let headingDegrees: String

   let isDimmed: Bool
   var isExpanded: Bool = false

   @Environment(\.accessibilityReduceMotion) private var reduceMotion

   /// Unwrapped course the rose is drawn against. Allowed to run past ±360.
   @State private var shownCourse: Double = 0

   private var hasCourse: Bool { course >= 0 }
   private var tapeHeight: CGFloat { isExpanded ? 62 : 52 }
   private var visibleSpan: Double { isExpanded ? 100 : 120 }

   var body: some View {
      VStack(spacing: -9) {
         ZStack {
            courseWindow

            RideHeadingRose(
               course: shownCourse,
               visibleSpan: visibleSpan,
               hasCourse: hasCourse,
               isDimmed: isDimmed,
               isExpanded: isExpanded
            )
            .mask(edgeFade)

            needle
         }
         .frame(height: tapeHeight)
         .padding(.horizontal, 6)
         .background(tray)

         readout
      }
      .onAppear { shownCourse = hasCourse ? course : 0 }
      .onChange(of: course) { _, newCourse in
         follow(newCourse)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Heading")
      .accessibilityValue(hasCourse ? "\(heading) \(headingDegrees)" : "Unknown")
      .accessibilityIdentifier("ride.heading")
   }

   // MARK: - Motion

   private func follow(_ newCourse: Double) {
      let target = newCourse >= 0 ? newCourse : 0
      var delta = (target - shownCourse).truncatingRemainder(dividingBy: 360)
      if delta > 180 { delta -= 360 }
      if delta < -180 { delta += 360 }

      let animation: Animation? = reduceMotion
         ? nil
         : .spring(response: 0.5, dampingFraction: 0.9)
      withAnimation(animation) {
         shownCourse += delta
      }
   }

   // MARK: - Pieces

   /// Smoked glass under the rose. The plate is brightest exactly where the
   /// ribbon sits, and ice ticks on sunlit gravel are invisible.
   private var tray: some View {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
         .fill(
            LinearGradient(
               colors: [Color.black.opacity(0.30), Color.black.opacity(0.50)],
               startPoint: .top,
               endPoint: .bottom
            )
         )
         .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
               .strokeBorder(
                  LinearGradient(
                     colors: [.white.opacity(0.16), .white.opacity(0.03)],
                     startPoint: .top,
                     endPoint: .bottom
                  ),
                  lineWidth: 1
               )
         }
   }

   /// The lit course window from the Watch bezel, laid flat: an ember pool
   /// under the needle that the rose slides through.
   private var courseWindow: some View {
      Ellipse()
         .fill(
            RadialGradient(
               colors: [
                  RideDashboardTheme.ember.opacity(isDimmed ? 0.08 : 0.30),
                  RideDashboardTheme.ember.opacity(0)
               ],
               center: .center,
               startRadius: 2,
               endRadius: 60
            )
         )
         .frame(width: 130, height: tapeHeight * 1.3)
         .blur(radius: 6)
         .allowsHitTesting(false)
   }

   private var needle: some View {
      RideCompassNeedle(height: isExpanded ? 20 : 17)
         .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
         .shadow(color: RideDashboardTheme.Compass.needleLight.opacity(hasCourse && !isDimmed ? 0.5 : 0), radius: 6)
         .frame(maxHeight: .infinity, alignment: .bottom)
         .padding(.bottom, 1)
         .opacity(hasCourse ? 1 : 0.45)
   }

   private var readout: some View {
      HStack(alignment: .firstTextBaseline, spacing: 5) {
         Text(heading)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .kerning(0.5)
            .foregroundStyle(hasCourse && !isDimmed ? RideDashboardTheme.ice : .white.opacity(0.4))

         if hasCourse {
            Text(headingDegrees)
               .font(.system(size: 13, weight: .bold, design: .rounded))
               .monospacedDigit()
               .foregroundStyle(isDimmed ? .white.opacity(0.35) : RideDashboardTheme.Compass.minty)
         }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 3)
      .rideGlassChrome(in: .capsule)
   }

   private var edgeFade: some View {
      LinearGradient(
         stops: [
            .init(color: .clear, location: 0),
            .init(color: .white, location: 0.12),
            .init(color: .white, location: 0.88),
            .init(color: .clear, location: 1)
         ],
         startPoint: .leading,
         endPoint: .trailing
      )
   }
}

// MARK: - Rose

/// The sliding rose. `course` is animatable, so SwiftUI hands the Canvas
/// every in-between value and the ticks glide instead of jumping.
private struct RideHeadingRose: View, Animatable {

   var course: Double
   let visibleSpan: Double
   let hasCourse: Bool
   let isDimmed: Bool
   let isExpanded: Bool

   var animatableData: Double {
      get { course }
      set { course = newValue }
   }

   private static let cardinals = ["N", "E", "S", "W"]
   private static let intercardinals = ["NE", "SE", "SW", "NW"]

   var body: some View {
      Canvas(rendersAsynchronously: false) { context, size in
         let pointsPerDegree = size.width / visibleSpan
         let margin = 12.0
         let first = ((course - visibleSpan / 2 - margin) / 5).rounded(.down) * 5
         let last = course + visibleSpan / 2 + margin
         let baseline = size.height - 1
         let labelY = size.height * 0.30
         let numeralY = size.height - (isExpanded ? 23 : 20)

         var degrees = first
         while degrees <= last {
            defer { degrees += 5 }

            let x = size.width / 2 + (degrees - course) * pointsPerDegree
            let mark = Int(RideHeadingTapeGeometry.normalized(degrees).rounded())
            let isCardinal = mark.isMultiple(of: 90)
            let isIntercardinal = !isCardinal && mark.isMultiple(of: 45)
            let isMajor = mark.isMultiple(of: 15)

            // Tick
            let tickHeight: CGFloat = isCardinal ? 13 : (isIntercardinal ? 10 : (isMajor ? 7 : 4))
            let tickWidth: CGFloat = isCardinal || isIntercardinal ? 2 : 1
            var tick = Path()
            tick.addRoundedRect(
               in: CGRect(x: x - tickWidth / 2, y: baseline - tickHeight, width: tickWidth, height: tickHeight),
               cornerSize: CGSize(width: tickWidth / 2, height: tickWidth / 2)
            )
            context.fill(tick, with: .color(tickColor(isCardinal: isCardinal, isMajor: isMajor || isIntercardinal)))

            // Label
            if isCardinal {
               let isNear = hasCourse && abs(degrees - course) <= 5
               let label = Text(Self.cardinals[mark / 90])
                  .font(RideBrandType.display(isNear ? (isExpanded ? 30 : 26) : (isExpanded ? 25 : 22)))
                  .foregroundStyle(cardinalColor(isNear: isNear))

               if isNear {
                  var glow = context
                  glow.addFilter(.shadow(color: RideDashboardTheme.Compass.nearRed.opacity(0.7), radius: 6))
                  glow.draw(label, at: CGPoint(x: x, y: labelY), anchor: .center)
               } else {
                  context.draw(label, at: CGPoint(x: x, y: labelY), anchor: .center)
               }
            } else if isIntercardinal {
               let label = Text(Self.intercardinals[(mark / 45 - 1) / 2])
                  .font(.system(size: isExpanded ? 14 : 12, weight: .bold, design: .rounded))
                  .foregroundStyle(Color.white.opacity(isDimmed ? 0.3 : 0.62))
               context.draw(label, at: CGPoint(x: x, y: labelY + 1), anchor: .center)
            } else if mark.isMultiple(of: 30) {
               let numeral = Text(String(mark))
                  .font(.system(size: 9, weight: .semibold, design: .rounded))
                  .monospacedDigit()
                  .foregroundStyle(Color.white.opacity(isDimmed ? 0.2 : 0.42))
               context.draw(numeral, at: CGPoint(x: x, y: numeralY), anchor: .center)
            }
         }
      }
   }

   private func cardinalColor(isNear: Bool) -> Color {
      if isDimmed { return .white.opacity(0.4) }
      return isNear ? RideDashboardTheme.Compass.nearRed : RideDashboardTheme.Compass.dialYellow
   }

   private func tickColor(isCardinal: Bool, isMajor: Bool) -> Color {
      if isDimmed { return .white.opacity(isCardinal ? 0.28 : 0.12) }
      if isCardinal { return RideDashboardTheme.ice.opacity(0.95) }
      return RideDashboardTheme.ice.opacity(isMajor ? 0.6 : 0.36)
   }
}

// MARK: - Needle

/// Two facets of green, lit from the upper left, so the arrow reads as a
/// solid rather than a flat glyph. The BigMetric needle, kept.
struct RideCompassNeedle: View {

   let height: CGFloat

   private var width: CGFloat { height * 0.92 }

   var body: some View {
      ZStack {
         NeedleFacet(side: .left)
            .fill(
               LinearGradient(
                  colors: [RideDashboardTheme.Compass.needleLight, RideDashboardTheme.Compass.needleMid],
                  startPoint: .top,
                  endPoint: .bottom
               )
            )

         NeedleFacet(side: .right)
            .fill(
               LinearGradient(
                  colors: [RideDashboardTheme.Compass.needleMid, RideDashboardTheme.Compass.needleDark],
                  startPoint: .top,
                  endPoint: .bottom
               )
            )

         NeedleFacet(side: .left)
            .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
      }
      .frame(width: width, height: height)
   }

   nonisolated private struct NeedleFacet: Shape {

      enum Side { case left, right }

      let side: Side

      func path(in rect: CGRect) -> Path {
         let tip = CGPoint(x: rect.midX, y: rect.minY)
         let notch = CGPoint(x: rect.midX, y: rect.maxY * 0.70)
         var path = Path()
         path.move(to: tip)
         switch side {
            case .left:
               path.addLine(to: notch)
               path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            case .right:
               path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
               path.addLine(to: notch)
         }
         path.closeSubpath()
         return path
      }
   }
}

#Preview {
   ZStack {
      RideAtmosphereBackground()
      VStack(spacing: 28) {
         RideHeadingRibbonView(course: 47, heading: "NE", headingDegrees: "47°", isDimmed: false)
         RideHeadingRibbonView(course: 2, heading: "N", headingDegrees: "2°", isDimmed: false, isExpanded: true)
         RideHeadingRibbonView(course: -1, heading: "—", headingDegrees: "—", isDimmed: false)
      }
      .padding()
   }
   .preferredColorScheme(.dark)
}
