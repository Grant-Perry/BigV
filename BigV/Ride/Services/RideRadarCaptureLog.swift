//
//  RideRadarCaptureLog.swift
//  BigV
//

#if DEBUG

import Foundation

/// Raw radar notifications on disk, debug builds only.
///
/// One line per notification — `<unix_ms> 3203 <hex>` — matching the
/// partymola/bike-radar-docs log format so the published reference decoders
/// can be run against captures from the actual RTL515. This file is how the
/// speed-byte question gets settled with data instead of guesses.
@MainActor
final class RideRadarCaptureLog {

   private let fileURL: URL
   private var handle: FileHandle?

   // MARK: - Initialization

   init?(fileManager: FileManager = .default, now: Date = .now) {
      guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
         return nil
      }

      let folder = documents.appending(path: "radar-captures", directoryHint: .isDirectory)

      do {
         try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
      } catch {
         DebugPrint(mode: .radar, "Capture folder failed: \(error.localizedDescription)")
         return nil
      }

      let stamp = now.formatted(.iso8601.year().month().day().timeSeparator(.omitted).time(includingFractionalSeconds: false))
         .replacingOccurrences(of: ":", with: "")
      fileURL = folder.appending(path: "capture-\(stamp).log")

      fileManager.createFile(atPath: fileURL.path(), contents: nil)
      handle = try? FileHandle(forWritingTo: fileURL)

      guard handle != nil else { return nil }

      DebugPrint(mode: .radar, "Capturing raw radar frames to \(fileURL.lastPathComponent)")
   }

   deinit {
      try? handle?.close()
   }

   // MARK: - Recording

   /// Appends one raw notification exactly as it came off the wire.
   func record(_ payload: Data, at now: Date = .now) {
      let milliseconds = Int(now.timeIntervalSince1970 * 1000)
      let hex = payload.map { String(format: "%02X", $0) }.joined()
      let line = "\(milliseconds) 3203 \(hex)\n"

      guard let data = line.data(using: .utf8) else { return }
      try? handle?.write(contentsOf: data)
   }
}

#endif
