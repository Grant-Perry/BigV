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
         observedDistance = Self.miles(from: distance) ?? observedDistance
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

      let rideTime = (app.staticTexts["ride.tile.rideTime"].value as? String) ?? ""
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

   /// Records a ride the same way, then walks its story: the history detail
   /// with its charts, and the full-screen map behind the inline one.
   @MainActor
   func testRideDetailTellsTheFullStory() throws {
      let app = XCUIApplication()
      app.launch()

      recordRetainableRide(in: app)

      app.buttons["DONE"].tap()

      // Into history, onto the newest ride.
      app.tabBars.buttons["Rides"].tap()

      let heroCard = app.scrollViews.buttons.firstMatch
      XCTAssertTrue(heroCard.waitForExistence(timeout: 10), "No ride card appeared in history.")

      // The landing page has to explain itself: an all-time summary, the
      // hero's explicit report invitation, and a legend naming the map's dots.
      XCTAssertTrue(app.staticTexts["LATEST RIDE"].exists, "Hero card label missing.")
      XCTAssertTrue(
         app.staticTexts["VIEW FULL REPORT"].exists,
         "Hero card lost its report call to action."
      )
      attachScreenshot(of: app, named: "Rides landing page")

      heroCard.tap()

      // The report sections built from stored samples must all be present.
      XCTAssertTrue(
         app.staticTexts["ELEVATION"].waitForExistence(timeout: 10),
         "Elevation card never appeared on the ride detail screen."
      )
      XCTAssertTrue(app.staticTexts["SPEED"].exists, "Speed card missing from ride detail.")
      XCTAssertTrue(app.staticTexts["RIDE TIME"].exists, "Hero stats missing from ride detail.")

      attachScreenshot(of: app, named: "Ride detail — report")

      app.swipeUp()
      attachScreenshot(of: app, named: "Ride detail — scrolled")
      app.swipeDown()

      // The map expands to full screen on a tap and comes back on close.
      let inlineMap = app.descendants(matching: .any)["detail.map"].firstMatch
      XCTAssertTrue(inlineMap.waitForExistence(timeout: 5), "Inline route map not found.")
      inlineMap.tap()

      let closeButton = app.buttons["Close map"]
      XCTAssertTrue(closeButton.waitForExistence(timeout: 5), "Full screen map never presented.")
      attachScreenshot(of: app, named: "Ride detail — full screen map")

      closeButton.tap()
      XCTAssertTrue(
         app.staticTexts["ELEVATION"].waitForExistence(timeout: 5),
         "Detail screen did not return after closing the full screen map."
      )
   }

   // MARK: - Recording

   /// Drives START → moving telemetry → END → summary, asserting each gate.
   @MainActor
   private func recordRetainableRide(in app: XCUIApplication) {
      let startButton = app.buttons["START"]
      XCTAssertTrue(startButton.waitForExistence(timeout: 10), "START control never appeared")
      startButton.tap()

      resolveHealthAccessIfAsked(app)

      XCTAssertTrue(
         app.buttons["PAUSE"].waitForExistence(timeout: 40),
         "GPS fix never acquired. Check that a moving location scenario is running."
      )

      let distance = app.staticTexts["ride.tile.distance"]
      XCTAssertTrue(distance.waitForExistence(timeout: 5), "Distance tile never appeared.")

      let retainableDistance = 0.05
      let deadline = Date().addingTimeInterval(90)
      var observedDistance = 0.0

      while Date() < deadline {
         observedDistance = Self.miles(from: distance) ?? observedDistance
         guard observedDistance < retainableDistance else { break }
         Thread.sleep(forTimeInterval: 1)
      }

      XCTAssertGreaterThanOrEqual(
         observedDistance,
         retainableDistance,
         "Ride reached only \(observedDistance) mi in 90 s; the scenario is stationary or too slow."
      )

      app.buttons["END"].tap()
      XCTAssertTrue(
         app.buttons["NEW RIDE"].waitForExistence(timeout: 10),
         "Summary never appeared after END."
      )
   }

   /// The tile's accessibility label is its title, so the numeral has to be
   /// read from the accessibility value ("0.05 MI") instead.
   @MainActor
   private static func miles(from tile: XCUIElement) -> Double? {
      guard let raw = tile.value as? String,
            let first = raw.split(separator: " ").first
      else { return nil }
      return Double(first)
   }

   /// Clears the HealthKit consent sheet a fresh simulator raises at ride
   /// start. Best effort by design: a denied grant costs the export, not the
   /// ride, and the test's subject is the detail screen.
   @MainActor
   private func resolveHealthAccessIfAsked(_ app: XCUIApplication) {
      let sheet = app.navigationBars["Health Access"]
      guard sheet.waitForExistence(timeout: 6) else { return }

      let turnOnAll = app.staticTexts["Turn On All"].firstMatch
      if turnOnAll.waitForExistence(timeout: 2) {
         turnOnAll.tap()
      }

      let allow = sheet.buttons["Allow"]
      if allow.exists && allow.isEnabled {
         allow.tap()
      } else if sheet.buttons["Don’t Allow"].exists {
         sheet.buttons["Don’t Allow"].tap()
      }
   }

   @MainActor
   private func attachScreenshot(of app: XCUIApplication, named name: String) {
      let screenshot = XCTAttachment(screenshot: app.screenshot())
      screenshot.name = name
      screenshot.lifetime = .keepAlways
      add(screenshot)
   }
}
