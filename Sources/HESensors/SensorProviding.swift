import Foundation
import HECore

/// Supplies a `CardioSensor` for any `Modality`. The capture pipeline depends only
/// on this protocol, so swapping real ⇄ mock sensors (Simulator, tests, the
/// developer "simulate device" toggle) is transparent.
public protocol SensorProviding: Sendable {
    /// The appropriate sensor for `modality` — real on capable hardware, otherwise
    /// the synthetic `Mock…` variant.
    func sensor(for modality: Modality) -> any CardioSensor
}

/// Default `SensorProviding`.
///
/// Resolution rules:
/// * **Phone modalities** (`.fingerPPG`, `.facialRPPG`, `.scg`, `.pcg`) → the real
///   sensor on a physical device, the `Mock…` sensor in the Simulator or when
///   `forceSimulation` is set. (Each real sensor also self-falls-back to its mock if
///   its framework is unavailable at runtime, so this is belt-and-braces.)
/// * **Device modalities** (`.deviceMultiWavelengthPPG`, `.deviceECG`,
///   `.deviceBioZ`) → `HeartelfieDeviceSensor` reading from the supplied
///   `HeartelfieBLEManager`. With no manager, or when simulating, the
///   `MockHeartelfieDeviceSensor` is used. (When the BLE manager itself is in
///   simulated mode, the device sensor still reads synthetic frames through it.)
///
/// The real GATT profile the device path binds to is centralized in
/// `HeartelfieConfig.BLE`.
public final class SensorFactory: SensorProviding, @unchecked Sendable {

    /// Developer "simulate device / simulate sensors" toggle. When `true`, every
    /// modality resolves to its `Mock…` variant regardless of hardware. Thread-safe.
    public var forceSimulation: Bool {
        get { lock.withLock { _forceSimulation } }
        set { lock.withLock { _forceSimulation = newValue } }
    }

    private var _forceSimulation: Bool
    private let lock = NSLock()
    private let deviceBLE: HeartelfieBLEManager?

    /// - Parameters:
    ///   - forceSimulation: force every sensor to its mock variant. Defaults to
    ///     `false`. Callers typically pass `isSimulatorBuild` or a debug flag.
    ///   - deviceBLE: the shared BLE manager backing device modalities. If `nil`,
    ///     device modalities always resolve to the mock device sensor.
    public init(forceSimulation: Bool = false, deviceBLE: HeartelfieBLEManager? = nil) {
        self._forceSimulation = forceSimulation
        self.deviceBLE = deviceBLE
    }

    public func sensor(for modality: Modality) -> any CardioSensor {
        let simulate = forceSimulation || Self.isSimulator

        switch modality {
        case .fingerPPG:
            return simulate ? MockCameraPPGSensor() : makeCameraPPG()
        case .facialRPPG:
            return simulate ? MockFaceRPPGSensor() : makeFaceRPPG()
        case .scg:
            return simulate ? MockMotionSCGSensor() : MotionSCGSensor()
        case .pcg:
            return simulate ? MockMicPCGSensor() : MicPCGSensor()
        case .deviceMultiWavelengthPPG, .deviceECG, .deviceBioZ:
            // Use the real device sensor only when we have a BLE manager and aren't
            // force-simulating; otherwise emit synthetic device frames.
            if !simulate, let ble = deviceBLE {
                return HeartelfieDeviceSensor(modality: modality, ble: ble)
            }
            return MockHeartelfieDeviceSensor(modality: modality)
        }
    }

    // MARK: - Hardware-isolated factory helpers

    /// `CameraPPGSensor` and `FaceRPPGSensor` are `@MainActor`. Constructing them
    /// requires hopping to the main actor; `MainActor.assumeIsolated` is safe here
    /// because the capture pipeline drives the factory from the main actor. If ever
    /// called off-main this falls back to the mock to stay correct.
    private func makeCameraPPG() -> any CardioSensor {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { CameraPPGSensor() }
        }
        return MockCameraPPGSensor()
    }

    private func makeFaceRPPG() -> any CardioSensor {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { FaceRPPGSensor() }
        }
        return MockFaceRPPGSensor()
    }

    /// Whether this build is running in the iOS Simulator (no real camera/IMU/BLE).
public static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}
