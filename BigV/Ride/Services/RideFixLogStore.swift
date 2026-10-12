//
//  RideFixLogStore.swift
//  BigV
//

import Foundation
import Observation

/// The GPS diagnostic log: one file per ride, on disk, shareable.
///
/// Three field reports of "0.0 mph with the clock running" were diagnosed from
/// GoPro frames because the only per-fix evidence lived in `DebugPrint`, which
/// a TestFlight build never emits. This store keeps the same lines — every
/// fix, every phase change, every receiver start and stop, every radar link
/// change — in a rolling file under Application Support, in Debug builds
/// always and in TestFlight when the rider flips the switch in Settings.
///
/// Main-actor cost is one array append per line. Formatting and I/O happen on
/// `RideFixLogWriter`, an actor, in batches: every few seconds while a file is
/// open, and when a ride ends or the app leaves the foreground.
@Observable
@MainActor
final class RideFixLogStore {

   // MARK: - Shared

   static let shared = RideFixLogStore(directory: RideFixLogStore.defaultDirectory)

   // MARK: - Tuning

   /// Past this a file stops growing; a stuck sensor cannot fill the phone.
   static let maximumFileBytes = 2_000_000

   /// Files kept, newest first. Five rides is a week of commuting.
   static let keptFileCount = 5

   private static let flushInterval: Duration = .seconds(5)

   private enum PreferenceKey {
      static let enabled = "gpsLog.enabled"
   }

   // MARK: - Published State

   /// The rider's switch for TestFlight builds. Debug builds ignore it: they
   /// always log.
   var isEnabled: Bool {
      didSet {
         guard isEnabled != oldValue else { return }
         UserDefaults.standard.set(isEnabled, forKey: PreferenceKey.enabled)
         if !isActive { closeFile() }
      }
   }

   /// Whether lines are being kept right now.
   var isActive: Bool {
      #if DEBUG
      true
      #else
      isEnabled
      #endif
   }

   /// Log files on disk, newest first. Refreshed when a file opens, when a
   /// batch lands, and when Settings asks to share.
   private(set) var logFileURLs: [URL] = []

   var latestLogURL: URL? { logFileURLs.first }

   // MARK: - Private State

   private let directory: URL
   /// False after a ride file is sealed, so a later idle note cannot open a
   /// second, empty file that crowds the real ride out of the last-five list.
   @ObservationIgnored private var acceptsNotes = true
   /// True while Delete all logs is removing files, so a fix cannot open a
   /// new one underneath the deletion.
   @ObservationIgnored private var isClearing = false
   /// A ride started during a clear. Opened once the files are gone.
   @ObservationIgnored private var reopenAfterClear = false
   @ObservationIgnored private var writer: RideFixLogWriter?
   @ObservationIgnored private var pending: [RideFixLogWriter.Entry] = []
   @ObservationIgnored private var flushTask: Task<Void, Never>?
   /// Appends and closes, in order. Settings waits on this before sharing.
   @ObservationIgnored private var writeTask: Task<Void, Never>?

   // MARK: - Initialization

   init(directory: URL) {
      self.directory = directory
      // On until the rider says otherwise: the owner wants logs from the next
      // TestFlight ride, and `bool(forKey:)` would read an unset key as off.
      self.isEnabled = UserDefaults.standard.object(forKey: PreferenceKey.enabled) as? Bool ?? true
      refreshFileList()
   }

   private static var defaultDirectory: URL {
      let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
         ?? FileManager.default.temporaryDirectory
      return base.appending(path: "gps-logs", directoryHint: .isDirectory)
   }

   // MARK: - Ride Boundaries

   /// Opens a fresh file. Called from START so each ride is its own file;
   /// anything noted before the first START of a launch opens one lazily.
   func beginRide() {
      guard isActive else { return }
      if isClearing {
         acceptsNotes = true
         reopenAfterClear = true
         return
      }
      acceptsNotes = true
      closeFile()
      openFile()
      note("ride log opened")
   }

   /// Flushes and closes the ride's file.
   func endRide() {
      if isClearing {
         acceptsNotes = false
         reopenAfterClear = false
         return
      }
      guard writer != nil else { return }
      note("ride log closed")
      acceptsNotes = false
      closeFile()
   }

   // MARK: - Noting

   /// Records one line. Cheap: the text is stored and stamped, nothing else
   /// happens on this actor.
   func note(_ line: String) {
      guard isActive, acceptsNotes, !isClearing else { return }
      if writer == nil { openFile() }
      pending.append(RideFixLogWriter.Entry(date: .now, text: line))
   }

   /// Hands buffered lines to the writer. Called on a timer while a file is
   /// open, at ride end, and when the scene leaves the foreground.
   func flush() {
      guard let writer, !pending.isEmpty else { return }
      let batch = pending
      pending.removeAll(keepingCapacity: true)
      enqueue(batch, to: writer, closeWhenDone: false)
   }

   /// Writes anything still buffered and re-reads the folder. Settings calls
   /// this before offering Share, so the file on screen is the file on disk.
   func refreshForDisplay() async {
      flush()
      await writeTask?.value
      refreshFileList()
   }

   /// Deletes every log file on disk. Lines still buffered are dropped.
   /// A ride that is recording starts a new file on its next fix.
   func deleteAllLogs() async {
      isClearing = true
      flushTask?.cancel()
      flushTask = nil
      pending.removeAll()

      let openWriter = writer
      writer = nil
      await writeTask?.value
      await openWriter?.close()

      let urls = (try? FileManager.default.contentsOfDirectory(
         at: directory,
         includingPropertiesForKeys: nil
      )) ?? []
      for url in urls where url.pathExtension == "log" {
         try? FileManager.default.removeItem(at: url)
      }
      logFileURLs = []

      isClearing = false
      if reopenAfterClear {
         reopenAfterClear = false
         beginRide()
      }
   }

   // MARK: - Files

   private func openFile() {
      do {
         try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      } catch {
         DebugPrint(mode: .sessionLifecycle, "GPS log folder failed: \(error.localizedDescription)")
         return
      }

      let stamp = Date.now.formatted(
         .iso8601.year().month().day().timeSeparator(.omitted).dateTimeSeparator(.standard)
            .time(includingFractionalSeconds: false)
      ).replacingOccurrences(of: ":", with: "")
      let url = directory.appending(path: "ride-\(stamp).log")
      // The empty file has to exist before the list refreshes, or Settings
      // still says "no log yet" for the whole ride.
      let path = url.path(percentEncoded: false)
      if !FileManager.default.fileExists(atPath: path),
         !FileManager.default.createFile(atPath: path, contents: nil) {
         DebugPrint(mode: .sessionLifecycle, "GPS log file failed")
         return
      }

      writer = RideFixLogWriter(fileURL: url, byteLimit: Self.maximumFileBytes)
      startFlushLoop()
      pruneOldFiles(keeping: Self.keptFileCount - 1, besides: url)
      refreshFileList()
   }

   private func closeFile() {
      flushTask?.cancel()
      flushTask = nil

      guard let writer else { return }
      let batch = pending
      pending.removeAll(keepingCapacity: true)
      self.writer = nil
      enqueue(batch, to: writer, closeWhenDone: true)
   }

   /// Serializes appends. A flush and a ride-end close can both be in flight;
   /// the close has to land after the flush or it shuts the handle first.
   private func enqueue(
      _ batch: [RideFixLogWriter.Entry],
      to writer: RideFixLogWriter,
      closeWhenDone: Bool
   ) {
      let previous = writeTask
      writeTask = Task { [weak self] in
         await previous?.value
         await writer.append(batch)
         if closeWhenDone {
            await writer.close()
         }
         self?.refreshFileList()
      }
   }

   private func startFlushLoop() {
      flushTask?.cancel()
      flushTask = Task { [weak self] in
         while !Task.isCancelled {
            do {
               try await Task.sleep(for: Self.flushInterval)
            } catch {
               return
            }
            self?.flush()
         }
      }
   }

   private func refreshFileList() {
      let urls = (try? FileManager.default.contentsOfDirectory(
         at: directory,
         includingPropertiesForKeys: nil
      )) ?? []

      let updated = urls
         .filter { $0.pathExtension == "log" }
         .sorted { $0.lastPathComponent > $1.lastPathComponent }
      if updated != logFileURLs {
         logFileURLs = updated
      }
   }

   private func pruneOldFiles(keeping count: Int, besides current: URL) {
      refreshFileList()
      let others = logFileURLs.filter { $0 != current }
      for url in others.dropFirst(count) {
         try? FileManager.default.removeItem(at: url)
      }
   }
}

// MARK: - Writer

/// Owns one log file's handle. An actor so formatting and `write` never run
/// on the main actor beside the ride.
actor RideFixLogWriter {

   struct Entry: Sendable {
      let date: Date
      let text: String
   }

   private let fileURL: URL
   private let byteLimit: Int
   private var handle: FileHandle?
   private var bytesWritten = 0
   private var isCapped = false

   init(fileURL: URL, byteLimit: Int) {
      self.fileURL = fileURL
      self.byteLimit = byteLimit
   }

   func append(_ entries: [Entry]) {
      guard !entries.isEmpty, !isCapped else { return }
      guard let handle = openHandleIfNeeded() else { return }

      var text = ""
      for entry in entries {
         text += Self.timestamp(entry.date) + " " + entry.text + "\n"
      }

      guard let data = text.data(using: .utf8) else { return }

      if bytesWritten + data.count > byteLimit {
         isCapped = true
         try? handle.write(contentsOf: Data("-- log capped at \(byteLimit) bytes --\n".utf8))
         return
      }

      try? handle.write(contentsOf: data)
      bytesWritten += data.count
   }

   func close() {
      try? handle?.close()
      handle = nil
   }

   private func openHandleIfNeeded() -> FileHandle? {
      if let handle { return handle }

      // `path()` percent-encodes spaces, so "Application Support" never
      // matches the real folder and every line is thrown away.
      let path = fileURL.path(percentEncoded: false)
      if !FileManager.default.fileExists(atPath: path) {
         guard FileManager.default.createFile(atPath: path, contents: nil) else { return nil }
      }
      handle = try? FileHandle(forWritingTo: fileURL)
      _ = try? handle?.seekToEnd()
      return handle
   }

   private static func timestamp(_ date: Date) -> String {
      date.formatted(.iso8601.time(includingFractionalSeconds: true))
   }
}
