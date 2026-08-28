//
//  RideRadarManager.swift
//  BigV
//

import CoreBluetooth
import Foundation

/// Delivers Varia radar frames to the ride session as an async stream.
///
/// Owns the Core Bluetooth central, the remembered peripheral, reconnection
/// and battery reads. It performs no threat math; decoding lives in
/// `RideRadarDecoder` and tracking in `RideRadarTracker`, exactly as
/// `RideLocationManager` leaves filtering to `RideTelemetryEngine`.
///
/// The central is created with a `nil` queue so every delegate callback lands
/// on the main queue, and the `NSObject` delegate bridge forwards through
/// `MainActor.assumeIsolated` — the alert path stays hop-free with no GCD.
///
/// `@Observable` so the pairing sheet can watch discovery, battery and device
/// info directly; the ride session keeps consuming the event stream.
@Observable
@MainActor
final class RideRadarManager {

   // MARK: - Preferences

   private enum PreferenceKey {
      static let peripheralIdentifier = "radar.peripheral.identifier"
      static let simulatorEnabled = "radar.simulator"
   }

   // MARK: - Discovery

   /// A radar seen during a pairing scan, before the rider has chosen it.
   struct Discovery: Identifiable, Equatable, Sendable {
      let id: UUID
      let name: String
   }

   // MARK: - Observable Pairing State

   /// Mirrors of the stream events, for the pairing sheet to observe.
   private(set) var connection: RideRadarConnectionState = .disconnected
   private(set) var batteryPercent: Int?
   private(set) var firmwareVersion: String?
   private(set) var modelName: String?
   private(set) var connectedName: String?

   /// Radars found while the pairing sheet is scanning.
   private(set) var discoveries: [Discovery] = []
   private(set) var isDiscovering = false

   private(set) var hasRememberedRadar: Bool
   private(set) var isSimulated = false

   /// Last rider-facing issue from the radio path. Cleared on a clean connect.
   private(set) var lastIssue: RideRadarIssue?

   /// Whether there is anything worth drawing a tape for.
   var isPairedOrSimulated: Bool { hasRememberedRadar || isSimulated }

   // MARK: - Private Properties

   @ObservationIgnored private var central: CBCentralManager?
   @ObservationIgnored private var bridge: RideRadarDelegateBridge?
   @ObservationIgnored private var peripheral: CBPeripheral?

   /// Strong references to scan results, keyed by identifier, so a tapped
   /// discovery can still be connected.
   @ObservationIgnored private var discoveredPeripherals: [UUID: CBPeripheral] = [:]

   @ObservationIgnored private var continuation: AsyncStream<RideRadarLinkEvent>.Continuation?
   @ObservationIgnored private var reconnectTask: Task<Void, Never>?
   @ObservationIgnored private var connectTimeoutTask: Task<Void, Never>?
   @ObservationIgnored private var reconnectAttempt = 0

   /// When we cancel a peripheral to start a fresh handshake, Core Bluetooth
   /// still delivers `didDisconnect` for that UUID. Park the next target here
   /// and start its connect only after that callback lands.
   @ObservationIgnored private var pendingConnect: CBPeripheral?

   /// 1 / 2 / 4 / 8 / 16 / 30 seconds, then hold at 30.
   @ObservationIgnored private let backoffLadder: [TimeInterval] = [1, 2, 4, 8, 16, 30]

   /// A hung `central.connect` never calls fail — Varia exclusivity and a
   /// radar still bonded to the Garmin app are the usual culprits. Bail out
   /// so the sheet does not sit on "Connecting…" forever.
   @ObservationIgnored private let connectTimeout: TimeInterval = 12

   #if DEBUG
   @ObservationIgnored private var captureLog: RideRadarCaptureLog?
   #endif

   @ObservationIgnored private let radarService = CBUUID(string: RideRadarGATT.serviceUUID)
   @ObservationIgnored private let threatCharacteristic = CBUUID(string: RideRadarGATT.threatCharacteristicUUID)
   @ObservationIgnored private let garminMemberService = CBUUID(string: RideRadarGATT.garminMemberServiceUUID)
   @ObservationIgnored private let batteryService = CBUUID(string: RideRadarGATT.batteryServiceUUID)
   @ObservationIgnored private let batteryCharacteristic = CBUUID(string: RideRadarGATT.batteryLevelCharacteristicUUID)
   @ObservationIgnored private let modelCharacteristic = CBUUID(string: RideRadarGATT.modelNumberCharacteristicUUID)
   @ObservationIgnored private let firmwareCharacteristic = CBUUID(string: RideRadarGATT.firmwareRevisionCharacteristicUUID)

   // MARK: - Initialization

   init() {
      hasRememberedRadar = UserDefaults.standard.string(
         forKey: PreferenceKey.peripheralIdentifier
      ) != nil
   }

   // MARK: - Updates

   /// Starts radar delivery. Any previous stream is torn down first.
   func startUpdates() -> AsyncStream<RideRadarLinkEvent> {
      stopUpdates()

      #if DEBUG
      if UserDefaults.standard.bool(forKey: PreferenceKey.simulatorEnabled) {
         DebugPrint(mode: .radar, "Radar simulator active — scripted traffic, no radio")
         isSimulated = true
         connection = .connected
         connectedName = "Simulated radar"
         firmwareVersion = "demo"
         modelName = "RTL515 (scripted)"
         batteryPercent = 87
         return RideRadarSimulator.demoLoop()
      }
      captureLog = RideRadarCaptureLog()
      #endif

      let (stream, continuation) = AsyncStream<RideRadarLinkEvent>.makeStream(
         bufferingPolicy: .bufferingNewest(16)
      )
      self.continuation = continuation

      let bridge = RideRadarDelegateBridge(manager: self)
      self.bridge = bridge
      central = CBCentralManager(delegate: bridge, queue: nil)

      DebugPrint(mode: .radar, "Radar updates started")
      return stream
   }

   func stopUpdates() {
      cancelConnectTimeout()
      reconnectTask?.cancel()
      reconnectTask = nil
      reconnectAttempt = 0

      if let peripheral, let central {
         central.cancelPeripheralConnection(peripheral)
      }
      peripheral = nil
      central = nil
      bridge = nil

      continuation?.finish()
      continuation = nil

      connection = .disconnected
      lastIssue = nil
      batteryPercent = nil
      firmwareVersion = nil
      modelName = nil
      connectedName = nil
      discoveries = []
      discoveredPeripherals = [:]
      isDiscovering = false
      isSimulated = false

      #if DEBUG
      captureLog = nil
      #endif

      DebugPrint(mode: .radar, "Radar updates stopped")
   }

   // MARK: - Pairing

   /// Switches the scan into pairing mode: discoveries are listed for the
   /// rider to choose from instead of auto-connecting to the first radar seen.
   func beginDiscovery() {
      guard !isSimulated else { return }

      // A hung auto-connect + an active scan is how the sheet got stuck on
      // "Connecting…" while still listing devices. Abort the in-flight attempt
      // so the rider can pick cleanly.
      cancelPendingConnection(reason: nil)

      isDiscovering = true
      discoveries = []
      discoveredPeripherals = [:]
      lastIssue = nil
      publishConnection(.scanning)

      guard let central, central.state == .poweredOn else { return }

      central.scanForPeripherals(withServices: [radarService, garminMemberService])
      DebugPrint(mode: .radar, "Pairing scan started")
   }

   /// Ends pairing mode. If nothing is connected and a radar is remembered or
   /// discoverable, the normal auto-connect flow resumes.
   func endDiscovery() {
      guard isDiscovering else { return }

      isDiscovering = false
      discoveries = []
      discoveredPeripherals = [:]

      guard let central, central.state == .poweredOn else { return }

      if connection == .connected {
         central.stopScan()
      } else if peripheral == nil || connection != .connecting {
         connectRememberedOrScan(with: central)
      }
   }

   /// Connects to a radar the rider chose from the pairing scan.
   func connect(to discoveryID: UUID) {
      guard let central,
            let chosen = discoveredPeripherals[discoveryID]
      else { return }

      isDiscovering = false
      discoveries = []
      central.stopScan()
      lastIssue = nil

      connect(chosen, with: central)
   }

   /// Aborts a stuck connect so the rider can scan again.
   func cancelConnecting() {
      cancelPendingConnection(reason: nil)
      publishConnection(.disconnected)
      DebugPrint(mode: .radar, "Connect cancelled by rider")
   }

   /// Drops the remembered radar so the next scan starts fresh.
   func forgetPeripheral() {
      UserDefaults.standard.removeObject(forKey: PreferenceKey.peripheralIdentifier)
      hasRememberedRadar = false
      firmwareVersion = nil
      modelName = nil
      connectedName = nil
      batteryPercent = nil
      lastIssue = nil

      cancelConnectTimeout()
      reconnectTask?.cancel()
      reconnectTask = nil

      // The disconnect callback owns the cleanup, so the delegate path stays
      // the single place connection state changes.
      if let peripheral, let central {
         central.cancelPeripheralConnection(peripheral)
      } else {
         peripheral = nil
         publishConnection(.disconnected)
      }

      DebugPrint(mode: .radar, "Radar forgotten")
   }

   // MARK: - Central Lifecycle

   fileprivate func centralDidUpdateState(_ central: CBCentralManager) {
      switch central.state {
         case .poweredOn:
            if isDiscovering {
               central.scanForPeripherals(withServices: [radarService, garminMemberService])
            } else {
               connectRememberedOrScan(with: central)
            }

         case .poweredOff:
            continuation?.yield(.issue(.bluetoothOff))
            publishConnection(.disconnected)

         case .unauthorized:
            continuation?.yield(.issue(.bluetoothUnauthorized))
            publishConnection(.disconnected)

         case .unsupported, .resetting, .unknown:
            publishConnection(.disconnected)

         @unknown default:
            publishConnection(.disconnected)
      }
   }

   private func connectRememberedOrScan(with central: CBCentralManager) {
      if let identifierString = UserDefaults.standard.string(forKey: PreferenceKey.peripheralIdentifier),
         let identifier = UUID(uuidString: identifierString),
         let remembered = central.retrievePeripherals(withIdentifiers: [identifier]).first {
         connect(remembered, with: central)
         return
      }

      // A service filter is mandatory for background scanning; the RTL family
      // advertises the radar service alongside Garmin's member service.
      publishConnection(.scanning)
      central.scanForPeripherals(withServices: [radarService, garminMemberService])
      DebugPrint(mode: .radar, "Scanning for a radar")
   }

   fileprivate func centralDidDiscover(
      _ discovered: CBPeripheral,
      advertisementData: [String: Any],
      with central: CBCentralManager
   ) {
      if isDiscovering {
         record(discovered, advertisementData: advertisementData)
         return
      }

      guard peripheral == nil else { return }

      central.stopScan()
      connect(discovered, with: central)
   }

   private func record(_ discovered: CBPeripheral, advertisementData: [String: Any]) {
      let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
         ?? discovered.name
         ?? "Radar"

      discoveredPeripherals[discovered.identifier] = discovered

      let discovery = Discovery(id: discovered.identifier, name: name)

      if let index = discoveries.firstIndex(where: { $0.id == discovery.id }) {
         discoveries[index] = discovery
      } else {
         discoveries.append(discovery)
         DebugPrint(mode: .radar, "Discovered \(name)")
      }
   }

   private func connect(_ target: CBPeripheral, with central: CBCentralManager) {
      // Always stop scanning first — scan + connect together is how the sheet
      // showed "Connecting…" and "Searching…" at the same time.
      cancelConnectTimeout()
      reconnectTask?.cancel()
      reconnectTask = nil
      central.stopScan()

      // A second `connect` on a peripheral that is already mid-handshake is a
      // silent no-op on iOS. Cancel first, then connect from the disconnect
      // callback so the new handshake actually starts.
      if connection == .connecting || connection == .connected, peripheral != nil {
         pendingConnect = target
         publishConnection(.connecting)
         armConnectTimeout(for: target)
         if let existing = peripheral {
            central.cancelPeripheralConnection(existing)
         }
         DebugPrint(mode: .radar, "Cancelling prior link before connecting to \(target.name ?? "radar")")
         return
      }

      startConnect(target, with: central)
   }

   private func startConnect(_ target: CBPeripheral, with central: CBCentralManager) {
      pendingConnect = nil
      peripheral = target
      target.delegate = bridge

      publishConnection(.connecting)
      // Skip EnableAutoReconnect on the handshake itself — it has been observed
      // to leave a pending connect without didConnect/didFail. We own reconnect.
      central.connect(target, options: nil)
      armConnectTimeout(for: target)

      DebugPrint(mode: .radar, "Connecting to \(target.name ?? "radar")")
   }

   fileprivate func centralDidConnect(_ connected: CBPeripheral) {
      guard connected.identifier == peripheral?.identifier else { return }

      cancelConnectTimeout()
      pendingConnect = nil
      reconnectAttempt = 0
      lastIssue = nil

      UserDefaults.standard.set(
         connected.identifier.uuidString,
         forKey: PreferenceKey.peripheralIdentifier
      )
      hasRememberedRadar = true
      connectedName = connected.name

      publishConnection(.connected)

      // Battery and device info are read alongside the radar service. The V2
      // stream (6A4E3204) is never discovered, never subscribed: it demands a
      // bond we cannot complete, and touching it early pins newer radars into
      // modes we cannot service.
      connected.discoverServices([
         radarService,
         batteryService,
         CBUUID(string: RideRadarGATT.deviceInformationServiceUUID)
      ])

      DebugPrint(mode: .radar, "Radar connected: \(connected.name ?? "unnamed")")
   }

   fileprivate func centralDidFailToConnect(_ failed: CBPeripheral, error: Error?) {
      cancelConnectTimeout()
      DebugPrint(mode: .radar, "Radar connect failed: \(error?.localizedDescription ?? "unknown")")

      if let pending = pendingConnect, let central {
         peripheral = nil
         startConnect(pending, with: central)
         return
      }

      guard failed.identifier == peripheral?.identifier || peripheral == nil else { return }

      peripheral = nil
      publishConnection(.disconnected)

      // Most common: the Garmin Varia app (or another bike app) still holds the
      // single BLE slot. Surface the actionable copy.
      publishIssue(.radarBusy)

      if !isDiscovering {
         scheduleReconnect()
      }
   }

   fileprivate func centralDidDisconnect(_ disconnected: CBPeripheral, error: Error?) {
      cancelConnectTimeout()

      if let pending = pendingConnect, let central {
         peripheral = nil
         startConnect(pending, with: central)
         return
      }

      guard disconnected.identifier == peripheral?.identifier else { return }

      publishConnection(.disconnected)
      batteryPercent = nil
      peripheral = nil

      if error != nil {
         publishIssue(.connectionLost)
      }

      // A forgotten radar must not be chased. Pairing scan owns the radio.
      guard hasRememberedRadar, !isDiscovering else { return }

      scheduleReconnect()
   }

   private func scheduleReconnect() {
      guard let central, central.state == .poweredOn, !isDiscovering else { return }

      let delay = backoffLadder[min(reconnectAttempt, backoffLadder.count - 1)]
      reconnectAttempt += 1

      reconnectTask?.cancel()
      reconnectTask = Task { [weak self] in
         try? await Task.sleep(for: .seconds(delay))
         guard let self, !Task.isCancelled, let central = self.central else { return }
         guard !self.isDiscovering, self.connection != .connected else { return }

         self.peripheral = nil
         self.connectRememberedOrScan(with: central)
      }

      DebugPrint(mode: .radar, "Radar reconnect in \(Int(delay))s")
   }

   private func armConnectTimeout(for target: CBPeripheral) {
      cancelConnectTimeout()
      let identifier = target.identifier

      connectTimeoutTask = Task { [weak self] in
         try? await Task.sleep(for: .seconds(self?.connectTimeout ?? 12))
         guard let self, !Task.isCancelled else { return }
         guard self.connection == .connecting else { return }
         guard self.peripheral?.identifier == identifier
            || self.pendingConnect?.identifier == identifier
         else { return }

         DebugPrint(mode: .radar, "Radar connect timed out")
         self.cancelPendingConnection(reason: .radarBusy)
         self.publishConnection(.disconnected)

         if !self.isDiscovering {
            self.scheduleReconnect()
         }
      }
   }

   private func cancelConnectTimeout() {
      connectTimeoutTask?.cancel()
      connectTimeoutTask = nil
   }

   /// Cancels any in-flight or live peripheral connection without scheduling
   /// a reconnect. Used before a fresh connect and when the rider starts a scan.
   private func cancelPendingConnection(reason: RideRadarIssue?) {
      cancelConnectTimeout()
      reconnectTask?.cancel()
      reconnectTask = nil
      pendingConnect = nil

      if let peripheral, let central {
         central.cancelPeripheralConnection(peripheral)
      }
      peripheral = nil
      connectedName = nil

      if let reason {
         publishIssue(reason)
      }
   }

   private func publishConnection(_ state: RideRadarConnectionState) {
      connection = state
      continuation?.yield(.connection(state))
   }

   private func publishIssue(_ issue: RideRadarIssue) {
      lastIssue = issue
      continuation?.yield(.issue(issue))
   }

   // MARK: - GATT

   fileprivate func peripheralDidDiscoverServices(_ discovered: CBPeripheral) {
      for service in discovered.services ?? [] {
         switch service.uuid {
            case radarService:
               discovered.discoverCharacteristics([threatCharacteristic], for: service)
            case batteryService:
               discovered.discoverCharacteristics([batteryCharacteristic], for: service)
            default:
               discovered.discoverCharacteristics(
                  [modelCharacteristic, firmwareCharacteristic],
                  for: service
               )
         }
      }
   }

   fileprivate func peripheralDidDiscoverCharacteristics(of service: CBService, on discovered: CBPeripheral) {
      for characteristic in service.characteristics ?? [] {
         switch characteristic.uuid {
            case threatCharacteristic:
               discovered.setNotifyValue(true, for: characteristic)
               DebugPrint(mode: .radar, "Subscribed to the threat stream")

            case batteryCharacteristic:
               discovered.readValue(for: characteristic)
               if characteristic.properties.contains(.notify) {
                  discovered.setNotifyValue(true, for: characteristic)
               }

            case modelCharacteristic, firmwareCharacteristic:
               discovered.readValue(for: characteristic)

            default:
               break
         }
      }
   }

   fileprivate func peripheralDidUpdateValue(for characteristic: CBCharacteristic) {
      guard let data = characteristic.value else { return }

      switch characteristic.uuid {
         case threatCharacteristic:
            ingest(data)

         case batteryCharacteristic:
            if let percent = data.first {
               batteryPercent = Int(percent)
               continuation?.yield(.battery(Int(percent)))
            }

         case modelCharacteristic:
            modelName = String(data: data, encoding: .utf8)?
               .trimmingCharacters(in: .whitespacesAndNewlines)

         case firmwareCharacteristic:
            firmwareVersion = String(data: data, encoding: .utf8)?
               .trimmingCharacters(in: .whitespacesAndNewlines)

         default:
            break
      }
   }

   // MARK: - Decoding

   private func ingest(_ data: Data) {
      #if DEBUG
      captureLog?.record(data)
      #endif

      switch RideRadarDecoder.classify(data) {
         case .heartbeat(let frame), .threat(let frame):
            continuation?.yield(.frame(frame))

         case .sectorAmplitude:
            break

         case .unknown:
            DebugPrint(mode: .radar, limit: 20, "Unknown radar payload: \(data.map { String(format: "%02X", $0) }.joined())")
      }
   }
}

// MARK: - Delegate Bridge

/// Forwards Core Bluetooth callbacks onto the main actor.
///
/// The central is constructed with a `nil` queue, so every callback already
/// arrives on the main queue. The `@preconcurrency` conformances let these
/// main-actor methods satisfy the nonisolated delegate requirements with a
/// runtime check instead of a hop — and the check always holds here.
@MainActor
private final class RideRadarDelegateBridge: NSObject,
   @preconcurrency CBCentralManagerDelegate,
   @preconcurrency CBPeripheralDelegate {

   private weak var manager: RideRadarManager?

   init(manager: RideRadarManager) {
      self.manager = manager
   }

   // MARK: - CBCentralManagerDelegate

   func centralManagerDidUpdateState(_ central: CBCentralManager) {
      manager?.centralDidUpdateState(central)
   }

   func centralManager(
      _ central: CBCentralManager,
      didDiscover peripheral: CBPeripheral,
      advertisementData: [String: Any],
      rssi RSSI: NSNumber
   ) {
      manager?.centralDidDiscover(peripheral, advertisementData: advertisementData, with: central)
   }

   func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
      manager?.centralDidConnect(peripheral)
   }

   func centralManager(
      _ central: CBCentralManager,
      didFailToConnect peripheral: CBPeripheral,
      error: Error?
   ) {
      manager?.centralDidFailToConnect(peripheral, error: error)
   }

   func centralManager(
      _ central: CBCentralManager,
      didDisconnectPeripheral peripheral: CBPeripheral,
      error: Error?
   ) {
      manager?.centralDidDisconnect(peripheral, error: error)
   }

   // MARK: - CBPeripheralDelegate

   func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
      manager?.peripheralDidDiscoverServices(peripheral)
   }

   func peripheral(
      _ peripheral: CBPeripheral,
      didDiscoverCharacteristicsFor service: CBService,
      error: Error?
   ) {
      manager?.peripheralDidDiscoverCharacteristics(of: service, on: peripheral)
   }

   func peripheral(
      _ peripheral: CBPeripheral,
      didUpdateValueFor characteristic: CBCharacteristic,
      error: Error?
   ) {
      manager?.peripheralDidUpdateValue(for: characteristic)
   }
}
