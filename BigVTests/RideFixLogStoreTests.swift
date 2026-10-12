//
//  RideFixLogStoreTests.swift
//  BigVTests
//

import Foundation
import Testing
@testable import BigV

struct RideFixLogStoreTests {

   /// Application Support has a space in it. `URL.path()` percent-encodes that
   /// space, and a writer that uses the encoded path creates nothing.
   @Test @MainActor func rideLogIsWrittenIntoAFolderWhoseNameContainsASpace() async throws {
      let root = FileManager.default.temporaryDirectory
         .appending(path: "Application Support \(UUID().uuidString)", directoryHint: .isDirectory)
      defer { try? FileManager.default.removeItem(at: root) }

      let store = RideFixLogStore(
         directory: root.appending(path: "gps-logs", directoryHint: .isDirectory)
      )
      store.isEnabled = true
      store.beginRide()
      store.note("fix lat=1 lon=2")
      store.endRide()
      await store.refreshForDisplay()

      let url = try #require(store.latestLogURL)
      let text = try String(contentsOf: url, encoding: .utf8)
      #expect(text.contains("ride log opened"))
      #expect(text.contains("fix lat=1 lon=2"))
      #expect(text.contains("ride log closed"))
      #expect(url.path(percentEncoded: false).contains("Application Support"))
   }
}
