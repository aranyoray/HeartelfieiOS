import Foundation

/// A specific, actionable reason a capture's signal quality is poor. Each issue
/// carries coaching copy that tells the user exactly how to fix it — never a
/// generic "bad signal" message.
public enum SQIIssue: String, Codable, Sendable, CaseIterable, Hashable, Identifiable {
    case motion
    case lowAmplitude
    case lowLight
    case saturation
    case noContact
    case tooShort
    case irregularCadence
    case ambientNoise
    case faceNotFound

    public var id: String { rawValue }

    /// Actionable, specific guidance shown in the SQI coach banner.
    public var coachingMessage: String {
        switch self {
        case .motion: return "Hold still — try resting your hand on a table."
        case .lowAmplitude: return "Press a little more gently and fully cover the lens."
        case .lowLight: return "Increase lighting or make sure the torch is on."
        case .saturation: return "Ease off the pressure — the sensor is washed out."
        case .noContact: return "Reposition your finger to fully cover the camera."
        case .tooShort: return "Stay in place a little longer to capture enough beats."
        case .irregularCadence: return "Keep steady — the beat-to-beat timing looks noisy."
        case .ambientNoise: return "Find a quieter spot to reduce background noise."
        case .faceNotFound: return "Center your face in the frame with even lighting."
        }
    }

    public var systemImage: String {
        switch self {
        case .motion: return "hand.raised.slash"
        case .lowAmplitude: return "wave.3.left"
        case .lowLight: return "lightbulb.slash"
        case .saturation: return "sun.max.trianglebadge.exclamationmark"
        case .noContact: return "hand.point.up.braille"
        case .tooShort: return "timer"
        case .irregularCadence: return "waveform.path"
        case .ambientNoise: return "speaker.wave.3"
        case .faceNotFound: return "face.dashed"
        }
    }
}

/// The result of the mandatory Signal Quality Index gate that runs *before* any
/// metric is computed. A reading is never produced from a signal whose
/// `isAcceptable` is `false`.
public struct SignalQuality: Codable, Sendable, Hashable {
    /// Normalised quality score in `0...1`.
    public let sqi: Double
    /// Whether the capture cleared the acceptance threshold.
    public let isAcceptable: Bool
    /// Specific, ordered issues to coach the user through (best fix first).
    public let issues: [SQIIssue]

    public init(sqi: Double, isAcceptable: Bool, issues: [SQIIssue]) {
        self.sqi = min(max(sqi, 0), 1)
        self.isAcceptable = isAcceptable
        self.issues = issues
    }

    /// A perfect-quality placeholder (e.g. for clean synthetic signals).
    public static let pristine = SignalQuality(sqi: 1.0, isAcceptable: true, issues: [])

    /// Qualitative band for display.
    public var band: Band {
        switch sqi {
        case ..<0.4: return .poor
        case ..<0.7: return .fair
        default: return .good
        }
    }

    public enum Band: String, Codable, Sendable, Hashable {
        case poor, fair, good
        public var displayName: String {
            switch self {
            case .poor: return "Poor"
            case .fair: return "Fair"
            case .good: return "Good"
            }
        }
    }
}
