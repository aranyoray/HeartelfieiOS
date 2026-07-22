import Foundation
import Combine
import HECore
import HESignal

#if canImport(CoreBluetooth)
@preconcurrency import CoreBluetooth
#endif

/// Central coordinator for the Heartelfie hardware device over BLE.
///
/// The manager is the single owner of the CoreBluetooth stack and the single
/// source of `DeviceState` truth. The feature layer observes `state`; the
/// `HeartelfieDeviceSensor` pulls raw frames from `stream(for:)`.
///
/// Two modes:
/// * **Real** — wraps `CBCentralManager`, scans for the Heartelfie service
///   (`HeartelfieConfig.BLE.serviceUUID`), connects, discovers the GATT
///   characteristics, and forwards notifications. All CoreBluetooth is guarded by
///   `#if canImport(CoreBluetooth)` so the type still compiles where the framework
///   is unavailable.
/// * **Simulated** — drives a `MockHeartelfiePeripheral`, republishing its
///   synthetic telemetry and signal streams. Used by the developer "simulate
///   device" toggle and automatically in the Simulator.
///
/// > Wiring note: the real GATT profile (service + characteristic UUIDs, control
/// > channel) is centralized in `HeartelfieConfig.BLE`. Swap those placeholders for
/// > the production firmware profile and this manager picks them up unchanged.
@MainActor
public final class HeartelfieBLEManager: ObservableObject {

    // MARK: - Published state

    /// Live connection / contact / battery / firmware state of the device.
    @Published public private(set) var state: DeviceState

    // MARK: - Simulation toggle

    /// When `true`, a `MockHeartelfiePeripheral` is used instead of CoreBluetooth.
    /// Flipping this restarts whatever session is appropriate for the new mode.
    public var isSimulated: Bool {
        didSet {
            guard oldValue != isSimulated else { return }
            handleSimulationChange()
        }
    }

    // MARK: - Mock backing

    private let mockPeripheral: MockHeartelfiePeripheral
    private var mockTelemetryTask: Task<Void, Never>?

    // MARK: - Real CoreBluetooth backing

    #if canImport(CoreBluetooth)
    private var central: CBCentralManager?
    private var bleDelegate: BLEDelegate?
    private var peripheral: CBPeripheral?
    /// Continuations for live characteristic notifications, keyed by modality.
    private var characteristicContinuations: [Modality: AsyncStream<SignalFrame>.Continuation] = [:]
    #endif

    private var didRequestScan = false

    // MARK: - Init

    /// - Parameter simulated: start in simulated mode (no CoreBluetooth). Defaults
    ///   to `false`; callers in the Simulator should pass `true` (the
    ///   `SensorFactory` does this automatically).
    public init(simulated: Bool = false) {
        self.isSimulated = simulated
        self.mockPeripheral = MockHeartelfiePeripheral()
        self.state = DeviceState(
            connection: .disconnected,
            contact: .unknown,
            deviceName: HeartelfieConfig.deviceName,
            isSimulated: simulated
        )
    }

    // MARK: - Public control surface

    /// Whether the real CoreBluetooth path is usable on this build. When the
    /// framework is unavailable the manager always behaves as simulated, so it
    /// compiles and runs everywhere (including the Simulator).
    private var usesRealBLE: Bool {
        #if canImport(CoreBluetooth)
        return !isSimulated
        #else
        return false
        #endif
    }

    /// Begin scanning for the Heartelfie device. In simulated mode this kicks off
    /// the synthetic scan → connect progression immediately.
    public func startScanning() {
        didRequestScan = true
        if usesRealBLE {
            #if canImport(CoreBluetooth)
            startRealScanning()
            #endif
        } else {
            startSimulatedSession()
        }
    }

    /// Connect to the discovered device. In simulated mode the mock auto-connects
    /// as part of its progression, so this simply ensures the session is running.
    public func connect() {
        if usesRealBLE {
            #if canImport(CoreBluetooth)
            connectReal()
            #endif
        } else {
            startSimulatedSession()
        }
    }

    /// Disconnect and tear down the active session (real or simulated).
    public func disconnect() {
        didRequestScan = false
        if usesRealBLE {
            #if canImport(CoreBluetooth)
            disconnectReal()
            #endif
        } else {
            stopSimulatedSession()
        }
    }

    /// A raw `SignalFrame` stream for a device modality, used by
    /// `HeartelfieDeviceSensor`. Returns an empty/finishing stream for non-device
    /// modalities. In simulated mode this is the mock peripheral's synthetic stream;
    /// on real hardware it forwards notifications for the matching characteristic.
    public func stream(for modality: Modality) -> AsyncStream<SignalFrame> {
        guard modality.requiresDevice else {
            return AsyncStream { $0.finish() }
        }
        if usesRealBLE {
            #if canImport(CoreBluetooth)
            return makeRealStream(for: modality)
            #else
            return makeSimulatedStream(for: modality)
            #endif
        } else {
            return makeSimulatedStream(for: modality)
        }
    }

    // MARK: - Simulation handling

    private func handleSimulationChange() {
        // Reflect the toggle in published state immediately.
        state.isSimulated = isSimulated
        if isSimulated {
            #if canImport(CoreBluetooth)
            disconnectReal()
            #endif
            if didRequestScan { startSimulatedSession() }
        } else {
            stopSimulatedSession()
            #if canImport(CoreBluetooth)
            if didRequestScan { startRealScanning() }
            #else
            // No CoreBluetooth: stay simulated regardless of the toggle.
            if didRequestScan { startSimulatedSession() }
            #endif
        }
    }

    private func startSimulatedSession() {
        // Subscribe (once) to the mock peripheral's telemetry and mirror it into
        // the published `DeviceState`.
        if mockTelemetryTask == nil {
            let peripheral = mockPeripheral
            mockTelemetryTask = Task { [weak self] in
                let stream = await peripheral.telemetryStream()
                for await telemetry in stream {
                    guard let self else { return }
                    await self.applyTelemetry(telemetry)
                }
            }
        }
        let peripheral = mockPeripheral
        Task { await peripheral.startConnecting() }
    }

    private func stopSimulatedSession() {
        mockTelemetryTask?.cancel()
        mockTelemetryTask = nil
        let peripheral = mockPeripheral
        Task { await peripheral.disconnect() }
        state = DeviceState(
            connection: .disconnected, contact: .unknown,
            deviceName: HeartelfieConfig.deviceName, isSimulated: isSimulated
        )
    }

    private func applyTelemetry(_ telemetry: MockHeartelfiePeripheral.Telemetry) {
        state = DeviceState(
            connection: telemetry.connection,
            contact: telemetry.contact,
            batteryLevel: telemetry.batteryLevel,
            firmwareVersion: telemetry.firmwareVersion,
            deviceName: telemetry.deviceName ?? HeartelfieConfig.deviceName,
            isSimulated: true
        )
    }

    private func makeSimulatedStream(for modality: Modality) -> AsyncStream<SignalFrame> {
        let peripheral = mockPeripheral
        return AsyncStream { continuation in
            let task = Task {
                let inner = await peripheral.signalStream(for: modality)
                for await frame in inner {
                    continuation.yield(frame)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - Real CoreBluetooth implementation

#if canImport(CoreBluetooth)
extension HeartelfieBLEManager {

    /// CoreBluetooth UUID for the primary Heartelfie service.
    private static var serviceCBUUID: CBUUID { CBUUID(string: HeartelfieConfig.BLE.serviceUUID) }

    /// All streaming/telemetry characteristics we discover and subscribe to.
    private static var characteristicCBUUIDs: [CBUUID] {
        [
            HeartelfieConfig.BLE.ppgStreamCharacteristic,
            HeartelfieConfig.BLE.ecgStreamCharacteristic,
            HeartelfieConfig.BLE.bioZStreamCharacteristic,
            HeartelfieConfig.BLE.batteryCharacteristic,
            HeartelfieConfig.BLE.contactStatusCharacteristic,
            HeartelfieConfig.BLE.firmwareCharacteristic
        ].map { CBUUID(string: $0) }
    }

    private func startRealScanning() {
        if central == nil {
            let delegate = BLEDelegate(owner: self)
            bleDelegate = delegate
            central = CBCentralManager(delegate: delegate, queue: .main)
        }
        // Scanning actually begins once the central reports `.poweredOn`
        // (`centralManagerDidUpdateState`); if it is already on, start now.
        if central?.state == .poweredOn {
            state.connection = .scanning
            central?.scanForPeripherals(withServices: [Self.serviceCBUUID])
        }
    }

    private func connectReal() {
        guard let central, let peripheral else {
            startRealScanning()
            return
        }
        state.connection = .connecting
        central.connect(peripheral)
    }

    private func disconnectReal() {
        if let central, let peripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        central?.stopScan()
        for continuation in characteristicContinuations.values { continuation.finish() }
        characteristicContinuations.removeAll()
        peripheral = nil
        if !isSimulated {
            state = DeviceState(
                connection: .disconnected, contact: .unknown,
                deviceName: HeartelfieConfig.deviceName, isSimulated: false
            )
        }
    }

    private func makeRealStream(for modality: Modality) -> AsyncStream<SignalFrame> {
        // `makeStream` lets us register the continuation under main-actor isolation
        // rather than mutating `characteristicContinuations` inside a `@Sendable`
        // build closure.
        characteristicContinuations[modality]?.finish()
        let (stream, continuation) = AsyncStream<SignalFrame>.makeStream()
        characteristicContinuations[modality] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.characteristicContinuations[modality] = nil }
        }
        return stream
    }

    // MARK: Delegate callbacks (invoked on the main queue)

    fileprivate func centralPoweredOn() {
        guard !isSimulated, didRequestScan else { return }
        state.connection = .scanning
        central?.scanForPeripherals(withServices: [Self.serviceCBUUID])
    }

    fileprivate func centralPoweredOff() {
        guard !isSimulated else { return }
        state = DeviceState(
            connection: .disconnected, contact: .unknown,
            deviceName: HeartelfieConfig.deviceName, isSimulated: false
        )
    }

    fileprivate func didDiscover(_ discovered: CBPeripheral) {
        guard peripheral == nil else { return }
        peripheral = discovered
        discovered.delegate = bleDelegate
        central?.stopScan()
        state.connection = .connecting
        central?.connect(discovered)
    }

    fileprivate func didConnect(_ connected: CBPeripheral) {
        state.connection = .connected
        state.deviceName = connected.name ?? HeartelfieConfig.deviceName
        connected.discoverServices([Self.serviceCBUUID])
    }

    fileprivate func didDisconnect() {
        for continuation in characteristicContinuations.values { continuation.finish() }
        characteristicContinuations.removeAll()
        peripheral = nil
        guard !isSimulated else { return }
        // Attempt a reconnect cycle if the user still wants the device.
        if didRequestScan {
            state.connection = .reconnecting
            startRealScanning()
        } else {
            state.connection = .disconnected
        }
    }

    fileprivate func didDiscoverServices(on peripheral: CBPeripheral) {
        for service in peripheral.services ?? [] where service.uuid == Self.serviceCBUUID {
            peripheral.discoverCharacteristics(Self.characteristicCBUUIDs, for: service)
        }
    }

    fileprivate func didDiscoverCharacteristics(for service: CBService, on peripheral: CBPeripheral) {
        for characteristic in service.characteristics ?? [] {
            // Subscribe to notify-capable streams; read the static-ish telemetry.
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        }
    }

    fileprivate func didUpdateValue(for characteristic: CBCharacteristic) {
        guard let data = characteristic.value else { return }
        let uuid = characteristic.uuid

        // Telemetry characteristics update `DeviceState`.
        if uuid == CBUUID(string: HeartelfieConfig.BLE.batteryCharacteristic) {
            if let raw = data.first { state.batteryLevel = Double(raw) / 100.0 }
            return
        }
        if uuid == CBUUID(string: HeartelfieConfig.BLE.firmwareCharacteristic) {
            state.firmwareVersion = String(data: data, encoding: .utf8) ?? state.firmwareVersion
            return
        }
        if uuid == CBUUID(string: HeartelfieConfig.BLE.contactStatusCharacteristic) {
            state.contact = Self.decodeContact(data)
            return
        }

        // Signal characteristics: decode samples and forward to the matching stream.
        guard let modality = Self.modality(forCharacteristic: uuid),
              let continuation = characteristicContinuations[modality] else { return }
        let frame = Self.decodeSignalFrame(data, modality: modality)
        continuation.yield(frame)
    }

    // MARK: Wire decoding (placeholder framing — replace with real firmware packet format)

    private static func modality(forCharacteristic uuid: CBUUID) -> Modality? {
        if uuid == CBUUID(string: HeartelfieConfig.BLE.ppgStreamCharacteristic) { return .deviceMultiWavelengthPPG }
        if uuid == CBUUID(string: HeartelfieConfig.BLE.ecgStreamCharacteristic) { return .deviceECG }
        if uuid == CBUUID(string: HeartelfieConfig.BLE.bioZStreamCharacteristic) { return .deviceBioZ }
        return nil
    }

    private static func decodeContact(_ data: Data) -> DeviceState.Contact {
        switch data.first {
        case 0: return DeviceState.Contact.none
        case 1: return .poor
        case 2: return .good
        default: return .unknown
        }
    }

    /// Decode a characteristic payload into a `SignalFrame`.
    ///
    /// The real firmware packet format (sample framing, endianness, scaling, the
    /// per-channel layout for MW-PPG) is defined alongside `HeartelfieConfig.BLE`.
    /// This placeholder interprets the payload as little-endian `Int16` samples and
    /// maps them onto the modality's channels so the path is exercisable end to end.
    private static func decodeSignalFrame(_ data: Data, modality: Modality) -> SignalFrame {
        let timestamp = Date().timeIntervalSince1970
        // Read little-endian Int16 samples without assuming buffer alignment
        // (BLE payloads are arbitrary byte runs). `loadUnaligned` is safe here.
        let sampleCount = data.count / MemoryLayout<Int16>.size
        var values = [Double](repeating: 0, count: sampleCount)
        data.withUnsafeBytes { raw in
            for i in 0..<sampleCount {
                let bits = raw.loadUnaligned(fromByteOffset: i * 2, as: UInt16.self)
                let sample = Int16(bitPattern: UInt16(littleEndian: bits))
                values[i] = Double(sample) / 32768.0
            }
        }

        switch modality {
        case .deviceMultiWavelengthPPG:
            // Expect interleaved [ir, ir2, red] triples; fall back gracefully.
            let ir = values.first ?? 0
            let ir2 = values.count > 1 ? values[1] : ir
            let red = values.count > 2 ? values[2] : ir
            return SignalFrame(timestamp: timestamp, samples: [
                SignalSample(timestamp: timestamp, value: ir, channel: .infrared),
                SignalSample(timestamp: timestamp, value: ir2, channel: .infrared2),
                SignalSample(timestamp: timestamp, value: red, channel: .red)
            ])
        case .deviceECG:
            return SignalFrame(timestamp: timestamp, value: values.first ?? 0, channel: .ecg)
        case .deviceBioZ:
            return SignalFrame(timestamp: timestamp, value: values.first ?? 0, channel: .bioImpedance)
        default:
            return SignalFrame(timestamp: timestamp, samples: [])
        }
    }
}

// MARK: - CBCentralManager / CBPeripheral delegate bridge

/// Bridges CoreBluetooth's `NSObject`-based delegate callbacks onto the
/// `@MainActor` manager.
///
/// The central is created with `queue: .main`, so every callback already runs on
/// the main thread. We therefore use `MainActor.assumeIsolated` to call into the
/// `@MainActor` manager *synchronously*, rather than spawning a `Task`. That avoids
/// having to send non-`Sendable` CoreBluetooth objects (`CBPeripheral`,
/// `CBCharacteristic`) across an isolation boundary — they never leave the main
/// thread.
private final class BLEDelegate: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
nonisolated(unsafe) weak var owner: HeartelfieBLEManager?

    init(owner: HeartelfieBLEManager) { self.owner = owner }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            switch central.state {
            case .poweredOn: owner?.centralPoweredOn()
            default: owner?.centralPoweredOff()
            }
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        MainActor.assumeIsolated { owner?.didDiscover(peripheral) }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated { owner?.didConnect(peripheral) }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        MainActor.assumeIsolated { owner?.didDisconnect() }
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        MainActor.assumeIsolated { owner?.didDisconnect() }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        MainActor.assumeIsolated { owner?.didDiscoverServices(on: peripheral) }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        MainActor.assumeIsolated { owner?.didDiscoverCharacteristics(for: service, on: peripheral) }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        MainActor.assumeIsolated { owner?.didUpdateValue(for: characteristic) }
    }
}
extension BLEDelegate: @unchecked Sendable {}
#endif
