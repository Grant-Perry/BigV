//
//  RideHeadingTapeGeometry.swift
//  BigV
//

import Foundation

/// Positions marks on a heading tape so the rider's course sits at center.
///
/// Pure wrap-around math. The view draws; this only answers where.
nonisolated enum RideHeadingTapeGeometry {

   /// Degrees in `[0, 360)`.
   static func normalized(_ degrees: Double) -> Double {
      let wrapped = degrees.truncatingRemainder(dividingBy: 360)
      return wrapped < 0 ? wrapped + 360 : wrapped
   }

   /// Signed shortest turn from `course` to `heading`, in `(-180, 180]`.
   static func signedDelta(from course: Double, to heading: Double) -> Double {
      var delta = normalized(heading) - normalized(course)
      if delta > 180 { delta -= 360 }
      if delta <= -180 { delta += 360 }
      return delta
   }

   /// X of a heading mark. The view's midpoint is the current course.
   static func xPosition(
      heading: Double,
      course: Double,
      width: Double,
      visibleSpan: Double
   ) -> Double {
      guard visibleSpan > 0, width > 0 else { return width / 2 }
      let delta = signedDelta(from: course, to: heading)
      return width / 2 + (delta / visibleSpan) * width
   }

   /// Whether a mark falls inside the tape window, plus a small fade margin.
   static func isVisible(
      heading: Double,
      course: Double,
      visibleSpan: Double,
      margin: Double = 18
   ) -> Bool {
      abs(signedDelta(from: course, to: heading)) <= visibleSpan / 2 + margin
   }
}
