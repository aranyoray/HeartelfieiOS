import Foundation

/// Which engine produced a reading's metrics. Surfaced on every result so the
/// user always knows whether a number came from on-device math, an on-device
/// model, or a cloud model.
public enum ProcessingEngine: String, Codable, Sendable, Hashable {
    case onDeviceDSP
    case onDeviceCoreML
    case cloud

    public var displayName: String {
        switch self {
        case .onDeviceDSP: return "On-device (signal processing)"
        case .onDeviceCoreML: return "On-device (CoreML)"
        case .cloud: return "Cloud model"
        }
    }

    public var systemImage: String {
        switch self {
        case .onDeviceDSP: return "function"
        case .onDeviceCoreML: return "cpu"
        case .cloud: return "cloud"
        }
    }
}

/// Model provenance attached to every reading. Cloud models in particular carry
/// data-license **attribution obligations**, so name + version + attribution are
/// first-class and always displayed.
public struct Provenance: Codable, Sendable, Hashable {
    public let engine: ProcessingEngine
    public let modelName: String
    public let modelVersion: String
    /// Attribution / license text that must be surfaced for this model, if any.
    public let attribution: String?

    public init(engine: ProcessingEngine, modelName: String, modelVersion: String, attribution: String? = nil) {
        self.engine = engine
        self.modelName = modelName
        self.modelVersion = modelVersion
        self.attribution = attribution
    }

    public var shortLabel: String { "\(modelName) v\(modelVersion)" }

    // MARK: Well-known provenances (placeholders — replace with real model metadata).

    /// On-device DSP pipeline (heart rate / HRV from vDSP peak detection).
    public static let onDeviceDSP = Provenance(
        engine: .onDeviceDSP,
        modelName: "DailyDil DSP",
        modelVersion: "1.0",
        attribution: nil
    )

    /// On-device CoreML SQI / rhythm-screen bundle (stub weights — replace).
    public static let onDeviceCoreML = Provenance(
        engine: .onDeviceCoreML,
        modelName: "DailyDil CoreML Suite",
        modelVersion: "0.1-stub",
        attribution: "Placeholder weights — drop in trained models. See README."
    )
}
