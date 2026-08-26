import Foundation

/// Where a raw physiological signal physically originates.
///
/// Surfacing the source is part of being *architecturally honest* about each
/// signal. Heartelfie screenings come from the phone cameras only.
public enum SignalSource: String, Codable, Sendable, CaseIterable, Hashable {
    /// Rear camera + torch (transmissive finger PPG).
    case rearCamera
    /// Front camera (contactless facial rPPG via Vision face ROI).
    case frontCamera

    public var displayName: String {
        switch self {
        case .rearCamera: return "Rear camera + torch"
        case .frontCamera: return "Front camera"
        }
    }

    /// SF Symbol representing the source.
    public var systemImage: String {
        switch self {
        case .rearCamera: return "camera.fill"
        case .frontCamera: return "person.crop.square.badge.video"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = SignalSource(rawValue: raw) ?? .rearCamera
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
