import Foundation

/// Protocol-oriented abstraction over every signal source. Concrete
/// implementations live in `HESensors` (`CameraPPGSensor`, `FaceRPPGSensor`,
/// `HeartelfieDeviceSensor`) — each paired with
/// a `Mock…` variant emitting synthetic frames so every flow runs in the
/// Simulator with no hardware.
public protocol CardioSensor: Sendable {
    /// What this sensor measures.
    var modality: Modality { get }

    /// The trust tier of data this sensor produces. Must equal `modality.tier`.
    var tier: MeasurementTier { get }

    /// Begin streaming timestamped frames. The stream finishes when `stop()` is
    /// called or the underlying source ends/errors.
    func start() async -> AsyncStream<SignalFrame>

    /// Stop streaming and release the underlying capture resources.
    func stop() async
}

public extension CardioSensor {
    /// Sensors must never misreport their tier.
    var tier: MeasurementTier { modality.tier }
}
