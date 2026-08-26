import Foundation

/// Phone screening modalities Heartelfie supports. Each is pinned to its trust
/// `tier`, physical `source`, and the metrics that source can legitimately produce.
///
/// Hardware-device modalities were removed from the product. Unknown legacy raw
/// values still decode as `.fingerPPG` so older saved readings can load.
public enum Modality: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    /// Transmissive finger PPG via the rear camera + torch.
    case fingerPPG
    /// Contactless facial rPPG via the front camera + Vision face ROI.
    case facialRPPG

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fingerPPG: return "Finger PPG"
        case .facialRPPG: return "Facial rPPG"
        }
    }

    public var shortName: String {
        switch self {
        case .fingerPPG: return "Finger PPG"
        case .facialRPPG: return "Face rPPG"
        }
    }

    public var tier: MeasurementTier { .screening }

    public var source: SignalSource {
        switch self {
        case .fingerPPG: return .rearCamera
        case .facialRPPG: return .frontCamera
        }
    }

    /// The metrics this modality is allowed to surface.
    public var supportedMetrics: [MetricKind] {
        switch self {
        case .fingerPPG:
            return [.heartRate, .hrvSDNN, .hrvRMSSD, .rhythmIrregularity, .respiratoryRate, .spo2Estimate]
        case .facialRPPG:
            return [.heartRate, .hrvSDNN, .hrvRMSSD]
        }
    }

    public var systemImage: String {
        switch self {
        case .fingerPPG: return "hand.point.up.left.fill"
        case .facialRPPG: return "face.smiling"
        }
    }

    /// One-line, non-diagnostic description of what the modality does.
    public var summary: String {
        switch self {
        case .fingerPPG:
            return "Place a fingertip over the rear camera and torch to screen heart rate, rhythm, and oxygen wellness."
        case .facialRPPG:
            return "Look at the front camera for a contactless heart-rate screen."
        }
    }

    /// The nominal sampling rate (Hz) the pipeline targets for this modality.
    public var nominalSampleRate: Double { 30 }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Modality(rawValue: raw) ?? .fingerPPG
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
