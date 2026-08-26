import Foundation
import HECore

/// Supplies a `CardioSensor` for any `Modality`. The capture pipeline depends only
/// on this protocol, so swapping real ⇄ mock sensors (Simulator, tests) is
/// transparent.
public protocol SensorProviding: Sendable {
    /// The appropriate sensor for `modality` — real on capable hardware, otherwise
    /// the synthetic `Mock…` variant.
    func sensor(for modality: Modality) -> any CardioSensor
}

/// Default `SensorProviding`.
///
/// Phone modalities (`.fingerPPG`, `.facialRPPG`) resolve to the real sensor on a
/// physical device, or the `Mock…` sensor in the Simulator or when
/// `forceSimulation` is set. Each real sensor also falls back to its mock if its
/// framework is unavailable at runtime.
public final class SensorFactory: SensorProviding, @unchecked Sendable {

    /// When `true`, every modality resolves to its `Mock…` variant regardless of
    /// hardware.
    private let forceSimulation: Bool

    /// - Parameter forceSimulation: force every sensor to its mock variant.
    public init(forceSimulation: Bool = false) {
        self.forceSimulation = forceSimulation
    }

    public func sensor(for modality: Modality) -> any CardioSensor {
        let simulate = forceSimulation || Self.isSimulator

        switch modality {
        case .fingerPPG:
            return simulate ? MockCameraPPGSensor() : makeCameraPPG()
        case .facialRPPG:
            return simulate ? MockFaceRPPGSensor() : makeFaceRPPG()
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

    /// Whether this build is running in the iOS Simulator (no real camera).
    public static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}
