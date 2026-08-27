//
//  RideDashboardUITests.swift
//  BigVUITests
//

import XCTest

/// End-to-end smoke test of the ride engine against simulated GPS.
///
/// Requires a moving location scenario on the target simulator, for example:
/// `xcrun simctl location <device> start --speed=8 --interval=1 <lat,lon> <lat,lon>`
///
/// The scenario has to cover real ground, not merely produce a fix:
/// `RideRetentionPolicy` discards any ride under 50 m, so a barely-moving
/// scenario ends with the session back on idle and no summary to assert against.
///
/// - Note: `nonisolated` opts out of the target's `MainActor` default isolation, because the
///   inherited `XCTestCase` members overridden below are themselves `nonisolated`. Test methods
///   re-apply `@MainActor` individually so `XCUIApplication` can be touched directly.
nonisolated final class RideDashboardUITests: XCTestCase {

   override func setUp() {
      continueAfterFailure = false
   }

   @MainActor
   func testStartingARideAccumulatesTelemetry() throws {
      let app = XCUIApplication()
      app.launch()

      let startButton = app.buttons["START"]
      XCTAssertTrue(startButton.waitForExistence(timeout: 10), "START control never appeared")
      startButton.tap()

      // Recording begins only once the engine accepts a usable fix.
      let pauseButton = app.buttons["PAUSE"]
      XCTAssertTrue(
         pauseButton.waitForExistence(timeout: 40),
         """
         GPS fix never acquired: still not recording 40 s after START. \
         Check that a moving location scenario is running on this simulator and \
         that location permission was granted.
         """
      )

      let distance = app.staticTexts["ride.tile.distance"]
      XCTAssertTrue(
         distance.waitForExistence(timeout: 5),
         "Distance tile never appeared, so the dashboard did not reach its recording layout."
      )

      // Miles, and comfortably past the 50 m the retention policy demands. Ending
      // below it discards the ride, so a smaller target would test nothing.
      let retainableDistance = 0.05
      let deadline = Date().addingTimeInterval(90)
      var observedDistance = 0.0

      while Date() < deadline {
         observedDistance = Double(distance.label) ?? observedDistance
         guard observedDistance < retainableDistance else { break }
         Thread.sleep(forTimeInterval: 1)
      }

      XCTAssertGreaterThanOrEqual(
         observedDistance,
         retainableDistance,
         """
         Ride reached only \(observedDistance) mi in 90 s of recording, short of the \
         \(retainableDistance) mi needed to clear the 50 m retention threshold. \
         Ending here would discard the ride. The location scenario is stationary or too slow.
         """
      )

      let screenshot = XCTAttachment(screenshot: app.screenshot())
      screenshot.name = "Ride dashboard while recording"
      screenshot.lifetime = .keepAlways
      add(screenshot)

      let rideTime = app.staticTexts["ride.tile.rideTime"].label
      XCTAssertNotEqual(rideTime, "0:00", "Ride clock never advanced past 0:00 while recording.")

      app.buttons["END"].tap()
      XCTAssertTrue(
         app.buttons["NEW RIDE"].waitForExistence(timeout: 10),
         """
         Summary never appeared after END. The ride had covered \(observedDistance) mi; \
         if that is under the 50 m retention threshold the session discarded it and \
         returned to idle instead of finishing.
         """
      )
   }
}
